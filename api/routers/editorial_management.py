import hashlib
import json
from fastapi import APIRouter,Depends,HTTPException,Request
from pydantic import ConfigDict,Field
from app.core.database import get_db
from app.dependencies import current_user
from app.editorial import require_publisher,format_editorial_content,visible_text,unique_ids
from starlette.concurrency import run_in_threadpool
from app.editorial_covers import claim_cover,consumed_cover,consume_cover,store_cover,MAX_IMAGE
from app.schemas import PostCreate
from routers.posts import POST_SELECT,_serialize_post,_validate_relations

router=APIRouter(prefix='/editorial',tags=['Administración editorial'])

class PostEdit(PostCreate):
    model_config=ConfigDict(extra='forbid')
    revision:str=Field(pattern=r'^[a-f0-9]{64}$')


def editable(cursor,id,user,lock=False):
    require_publisher(user)
    cursor.execute(POST_SELECT.replace(' FROM blog b', ',d.autor_id AS owner_id FROM blog b',1)+' WHERE b.id_blog=%s'+(' FOR UPDATE' if lock else ''),(id,))
    row=cursor.fetchone()
    if not row or (row['owner_id']!=user['id_usr'] and user['tip_usu']!=3):raise HTTPException(404,'Publicación no encontrada')
    cursor.execute('SELECT artista_id FROM blog_artista WHERE blog_id=%s ORDER BY artista_id',(id,));artists=[r['artista_id'] for r in cursor.fetchall()]
    cursor.execute('SELECT album_id FROM blog_album WHERE blog_id=%s ORDER BY album_id',(id,));albums=[r['album_id'] for r in cursor.fetchall()]
    snapshot={key:row.get(key) for key in ('titulo','descripcion','tags','contenido','estado','imagen','fecha_publicacion','owner_id')}
    snapshot.update(artist_ids=artists,album_ids=albums)
    revision=hashlib.sha256(json.dumps(snapshot,sort_keys=True,default=str,ensure_ascii=False).encode()).hexdigest()
    return {'post':_serialize_post(row),'artist_ids':artists,'album_ids':albums,'revision':revision}

@router.get('/posts')
def list_editorial(user=Depends(current_user),connection=Depends(get_db)):
    require_publisher(user)
    cursor=connection.cursor(dictionary=True)
    try:
        where='' if user['tip_usu']==3 else ' WHERE d.autor_id=%s'
        params=() if user['tip_usu']==3 else (user['id_usr'],)
        cursor.execute(POST_SELECT+where+' ORDER BY d.fecha_actualizacion DESC,b.id_blog DESC',params)
        return {'posts':[_serialize_post(row) for row in cursor.fetchall()]}
    finally:cursor.close()

@router.get('/posts/{post_id}')
def get_editorial(post_id:int,user=Depends(current_user),connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:return editable(cursor,post_id,user)
    finally:cursor.close()

@router.put('/posts/{post_id}')
def update_editorial(post_id:int,body:PostEdit,user=Depends(current_user),connection=Depends(get_db)):
    require_publisher(user)
    title=body.title.strip()
    content=format_editorial_content(body.content,title)
    if len(title)<3 or not visible_text(content):raise HTTPException(422,'Revisa el título y el contenido de la publicación')
    artists=unique_ids(body.artist_ids,'artist_ids');albums=unique_ids(body.album_ids,'album_ids')
    cursor=connection.cursor(dictionary=True)
    try:
        current=editable(cursor,post_id,user,True)
        cover=claim_cover(cursor,body.cover_token,user)
        if consumed_cover(cover,body,post_id):
            if cover['result_revision']!=current['revision']:raise HTTPException(409,'Esta publicación cambió después del guardado. Vuelve a abrirla.')
            connection.commit();return current
        if current['revision']!=body.revision:raise HTTPException(409,'Esta publicación cambió en otra sesión. Copia tus cambios y vuelve a abrirla antes de guardar.')
        _validate_relations(cursor,artists,albums)
        cursor.execute('UPDATE blog SET titulo=%s,`desc`=%s,tags=%s WHERE id_blog=%s',(title,(body.description or '').strip() or None,(body.tags or '').strip() or None,post_id))
        cursor.execute("UPDATE blog_detalle SET contenido=%s,estado=%s,fecha_publicacion=CASE WHEN %s='publicado' THEN COALESCE(fecha_publicacion,NOW()) ELSE NULL END WHERE blog_id=%s",(content,body.state,body.state,post_id))
        cursor.execute('DELETE FROM blog_album WHERE blog_id=%s',(post_id,))
        cursor.execute('DELETE FROM blog_artista WHERE blog_id=%s',(post_id,))
        if artists:cursor.executemany('INSERT INTO blog_artista(blog_id,artista_id) VALUES (%s,%s)',[(post_id,id) for id in artists])
        if albums:cursor.executemany('INSERT INTO blog_album(blog_id,album_id) VALUES (%s,%s)',[(post_id,id) for id in albums])
        if cover:
            cursor.execute('UPDATE blog SET img=%s WHERE id_blog=%s',(cover['filename'],post_id))
        result=editable(cursor,post_id,user)
        consume_cover(cursor,cover,body,post_id,result['revision'])
        connection.commit();return result
    except Exception:
        connection.rollback();raise
    finally:cursor.close()


@router.post('/covers')
async def upload_cover(request:Request,user=Depends(current_user),connection=Depends(get_db)):
    require_publisher(user)
    data=bytearray()
    async for chunk in request.stream():
        if len(data)+len(chunk)>MAX_IMAGE:raise HTTPException(413,'La portada debe pesar como máximo 5 MB.')
        data.extend(chunk)
    if not data:raise HTTPException(422,'Selecciona una portada.')
    return await run_in_threadpool(store_cover,bytes(data),user,connection)
