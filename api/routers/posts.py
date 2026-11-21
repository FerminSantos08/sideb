from fastapi import APIRouter, Depends, HTTPException, status
from app.core.database import get_db
from app.dependencies import current_user
from app.editorial import format_editorial_content, require_publisher, unique_ids, unique_slug, visible_text
from app.schemas import CommentCreate, PostCreate
from app.editorial_covers import claim_cover,consumed_cover,consume_cover
from app.utils import publication_image_url, serialize_media

from routers.reactions import enabled as reactions_enabled

router = APIRouter(prefix="/posts", tags=["Editorial"])
REACTIONS_SELECT = "(SELECT COUNT(*) FROM post_reactions pr WHERE pr.blog_id=b.id_blog)" if reactions_enabled() else "0"
POST_SELECT = f"""SELECT b.id_blog AS id, b.titulo, b.`desc` AS descripcion, b.img AS imagen, b.tags, b.slug, d.contenido, d.estado, d.fecha_publicacion, COALESCE(p.alias,u.nom_usr) AS autor, r.nombre AS rol_autor, (SELECT COUNT(*) FROM comentarios c WHERE c.blog_id=b.id_blog AND c.estatus='visible') AS comments_count, {REACTIONS_SELECT} AS reactions_count FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog JOIN usuario u ON u.id_usr=d.autor_id JOIN rol r ON r.id_rol=u.tip_usu LEFT JOIN perfil_usuario p ON p.usr_id=u.id_usr"""

@router.get("")
def listar_posts(connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(POST_SELECT + " WHERE d.estado='publicado' AND d.fecha_publicacion <= NOW() ORDER BY d.fecha_publicacion DESC")
        posts = [_serialize_post(row) for row in cursor.fetchall()]
        return {"success": True, "total": len(posts), "posts": posts}
    finally: cursor.close()


@router.get("/mine")
def listar_mis_publicaciones(user=Depends(current_user), connection=Depends(get_db)):
    require_publisher(user)
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(
            POST_SELECT + " WHERE d.autor_id=%s ORDER BY d.fecha_actualizacion DESC",
            (user["id_usr"],),
        )
        return {"posts": [_serialize_post(row) for row in cursor.fetchall()]}
    finally:
        cursor.close()


@router.get("/editorial/options")
def opciones_editoriales(user=Depends(current_user), connection=Depends(get_db)):
    require_publisher(user)
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id_artista AS id,nombre FROM artista WHERE activo=TRUE ORDER BY nombre")
        artists = cursor.fetchall()
        cursor.execute(
            """SELECT al.id_album AS id,al.artista_id AS artist_id,al.titulo,
            ar.nombre AS artist FROM album al JOIN artista ar ON ar.id_artista=al.artista_id
            ORDER BY ar.nombre,al.titulo"""
        )
        return {"artists": artists, "albums": cursor.fetchall()}
    finally:
        cursor.close()


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_publicacion(
    body: PostCreate,
    user=Depends(current_user),
    connection=Depends(get_db),
):
    require_publisher(user)
    title = body.title.strip()
    description = body.description.strip() if body.description else None
    tags = body.tags.strip() if body.tags else None
    content = format_editorial_content(body.content, title)
    if len(title) < 3:
        raise HTTPException(status_code=422, detail="El titulo debe tener al menos 3 caracteres")
    if not visible_text(content):
        raise HTTPException(status_code=422, detail="Escribe el contenido de la publicacion")

    artist_ids = unique_ids(body.artist_ids, "artist_ids")
    album_ids = unique_ids(body.album_ids, "album_ids")
    cursor = connection.cursor(dictionary=True)
    try:
        cover=claim_cover(cursor,body.cover_token,user)
        if consumed_cover(cover,body):
            cursor.execute(POST_SELECT+' WHERE b.id_blog=%s',(cover['blog_id'],))
            row=cursor.fetchone()
            if not row:raise HTTPException(404,'Publicación no encontrada')
            connection.commit()
            return {'post':_serialize_post(row)}
        _validate_relations(cursor, artist_ids, album_ids)
        slug = unique_slug(cursor, title)
        cursor.execute(
            "INSERT INTO blog (titulo, `desc`, tags, slug) VALUES (%s,%s,%s,%s)",
            (title, description, tags, slug),
        )
        post_id = cursor.lastrowid
        cursor.execute(
            """INSERT INTO blog_detalle
            (blog_id, contenido, autor_id, estado, fecha_publicacion)
            VALUES (%s,%s,%s,%s,CASE WHEN %s='publicado' THEN NOW() ELSE NULL END)""",
            (post_id, content, user["id_usr"], body.state, body.state),
        )
        if artist_ids:
            cursor.executemany(
                "INSERT INTO blog_artista (blog_id, artista_id) VALUES (%s,%s)",
                [(post_id, artist_id) for artist_id in artist_ids],
            )
        if album_ids:
            cursor.executemany(
                "INSERT INTO blog_album (blog_id, album_id) VALUES (%s,%s)",
                [(post_id, album_id) for album_id in album_ids],
            )
        if cover:
            cursor.execute('UPDATE blog SET img=%s WHERE id_blog=%s',(cover['filename'],post_id))
            consume_cover(cursor,cover,body,post_id)
        connection.commit()
        cursor.execute(POST_SELECT + " WHERE b.id_blog=%s", (post_id,))
        return {"post": _serialize_post(cursor.fetchone())}
    except HTTPException:
        connection.rollback()
        raise
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


def _validate_relations(cursor, artist_ids: list[int], album_ids: list[int]) -> None:
    if artist_ids:
        placeholders = ",".join(["%s"] * len(artist_ids))
        cursor.execute(
            f"SELECT id_artista FROM artista WHERE id_artista IN ({placeholders})",
            tuple(artist_ids),
        )
        if len(cursor.fetchall()) != len(artist_ids):
            raise HTTPException(status_code=422, detail="Uno o mas artistas no existen")
    if not album_ids:
        return
    if not artist_ids:
        raise HTTPException(
            status_code=422,
            detail="Selecciona un artista antes de asociar albumes",
        )
    placeholders = ",".join(["%s"] * len(album_ids))
    cursor.execute(
        f"SELECT id_album,artista_id FROM album WHERE id_album IN ({placeholders})",
        tuple(album_ids),
    )
    albums = cursor.fetchall()
    if len(albums) != len(album_ids) or any(
        album["artista_id"] not in artist_ids for album in albums
    ):
        raise HTTPException(
            status_code=422,
            detail="Cada album debe pertenecer a un artista relacionado",
        )

@router.get("/slug/{slug}")
def obtener_post_por_slug(slug: str, connection=Depends(get_db)): return _post(connection, "b.slug=%s", (slug,))
@router.get("/{post_id}")
def obtener_post(post_id: int, connection=Depends(get_db)): return _post(connection, "b.id_blog=%s", (post_id,))

def _post(connection, clause, values):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(POST_SELECT + f" WHERE {clause} AND d.estado='publicado' AND d.fecha_publicacion <= NOW()", values)
        post = cursor.fetchone()
        if not post: raise HTTPException(status_code=404, detail="Publicación no encontrada")
        return {"success": True, "post": _serialize_post(post)}
    finally: cursor.close()


def _serialize_post(post: dict) -> dict:
    post["imagen"] = publication_image_url(post.get("imagen"))
    return post

@router.get("/{post_id}/comments")
def listar_comentarios(post_id: int, connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT 1 FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog WHERE b.id_blog=%s AND d.estado='publicado' AND d.fecha_publicacion <= NOW()", (post_id,))
        if not cursor.fetchone(): raise HTTPException(status_code=404, detail="Publicación no encontrada")
        cursor.execute("SELECT c.id_com AS id, c.comentario, c.fecha, COALESCE(p.alias,u.nom_usr) AS autor, p.avatar_url FROM comentarios c JOIN usuario u ON u.id_usr=c.usr_id LEFT JOIN perfil_usuario p ON p.usr_id=u.id_usr WHERE c.blog_id=%s AND c.estatus='visible' ORDER BY c.fecha ASC", (post_id,))
        return {"comments": [serialize_media(row, "avatar_url") for row in cursor.fetchall()]}
    finally: cursor.close()

@router.post("/{post_id}/comments", status_code=status.HTTP_201_CREATED)
def crear_comentario(post_id: int, body: CommentCreate, user=Depends(current_user), connection=Depends(get_db)):
    comentario = body.comentario.strip()
    if not comentario: raise HTTPException(status_code=422, detail="El comentario no puede estar vacío")
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT 1 FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog WHERE b.id_blog=%s AND d.estado='publicado' AND d.fecha_publicacion <= NOW()", (post_id,))
        if not cursor.fetchone(): raise HTTPException(status_code=404, detail="Publicación no encontrada")
        cursor.execute("INSERT INTO comentarios (comentario, usr_id, blog_id) VALUES (%s,%s,%s)", (comentario, user["id_usr"], post_id)); connection.commit()
        return {"id": cursor.lastrowid, "comentario": comentario}
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()
