from fastapi import APIRouter,Depends,HTTPException
from app.core.database import get_db
from app.dependencies import current_user
from routers.posts import POST_SELECT,_serialize_post

router=APIRouter(prefix='/library',tags=['Publicaciones guardadas'])

@router.get('/posts')
def saved_posts(user=Depends(current_user),connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT blog_id FROM guardado_publicacion WHERE usr_id=%s ORDER BY fecha_guardado DESC', (user['id_usr'],))
        ids=[row['blog_id'] for row in cursor.fetchall()]
        cursor.execute(POST_SELECT+''' JOIN guardado_publicacion g ON g.blog_id=b.id_blog
            WHERE g.usr_id=%s AND d.estado='publicado' AND d.fecha_publicacion<=NOW()
            ORDER BY g.fecha_guardado DESC,b.id_blog DESC''',(user['id_usr'],))
        return {'posts':[_serialize_post(row) for row in cursor.fetchall()],'saved_ids':ids}
    finally:cursor.close()

@router.put('/posts/{post_id}',status_code=204)
def save_post(post_id:int,user=Depends(current_user),connection=Depends(get_db)):
    cursor=connection.cursor()
    try:
        cursor.execute("SELECT 1 FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog WHERE b.id_blog=%s AND d.estado='publicado' AND d.fecha_publicacion<=NOW() FOR SHARE",(post_id,))
        if not cursor.fetchone():raise HTTPException(404,'Publicación no disponible')
        cursor.execute('INSERT INTO guardado_publicacion(usr_id,blog_id) VALUES (%s,%s) ON DUPLICATE KEY UPDATE blog_id=VALUES(blog_id)',(user['id_usr'],post_id))
        connection.commit()
    except Exception:
        connection.rollback();raise
    finally:cursor.close()

@router.delete('/posts/{post_id}',status_code=204)
def remove_saved(post_id:int,user=Depends(current_user),connection=Depends(get_db)):
    cursor=connection.cursor()
    try:
        cursor.execute('DELETE FROM guardado_publicacion WHERE usr_id=%s AND blog_id=%s',(user['id_usr'],post_id));connection.commit()
    except Exception:
        connection.rollback();raise
    finally:cursor.close()
