from fastapi import APIRouter, Depends, HTTPException
from app.core.database import get_db
from app.utils import publication_image_url, serialize_media
router = APIRouter(tags=["Artistas y catálogo"])

@router.get("/artists")
def listar_artistas(connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try: cursor.execute("SELECT id_artista AS id,nombre,biografia,imagen,genero FROM artista WHERE activo=TRUE ORDER BY nombre"); return {"artists":[serialize_media(row,"imagen") for row in cursor.fetchall()]}
    finally: cursor.close()
@router.get("/artists/{artist_id}")
def detalle_artista(artist_id:int, connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id_artista AS id,nombre,biografia,imagen,genero FROM artista WHERE id_artista=%s AND activo=TRUE",(artist_id,)); artist=cursor.fetchone()
        if not artist: raise HTTPException(status_code=404,detail="Artista no encontrado")
        cursor.execute("SELECT id_album AS id,titulo,fecha_lanzamiento,portada,tipo FROM album WHERE artista_id=%s ORDER BY fecha_lanzamiento DESC,titulo",(artist_id,)); artist["albums"]=[serialize_media(row,"portada") for row in cursor.fetchall()]
        cursor.execute("SELECT b.id_blog AS id,b.titulo,b.`desc` AS descripcion,b.img AS imagen,b.tags,b.slug,d.fecha_publicacion,COALESCE(p.alias,u.nom_usr) AS autor,r.nombre AS rol_autor FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog JOIN blog_artista ba ON ba.blog_id=b.id_blog JOIN usuario u ON u.id_usr=d.autor_id JOIN rol r ON r.id_rol=u.tip_usu LEFT JOIN perfil_usuario p ON p.usr_id=u.id_usr WHERE ba.artista_id=%s AND d.estado='publicado' AND d.fecha_publicacion IS NOT NULL AND d.fecha_publicacion<=NOW() ORDER BY d.fecha_publicacion DESC",(artist_id,))
        artist["posts"] = cursor.fetchall()
        for post in artist["posts"]:
            post["imagen"] = publication_image_url(post.get("imagen"))
        return serialize_media(artist,"imagen")
    finally: cursor.close()
@router.get("/categories")
def listar_categorias(connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try: cursor.execute("SELECT c.id_categoria AS id,c.nombre,c.descripcion,COUNT(p.id_producto) AS total_productos FROM categoria_producto c LEFT JOIN producto p ON p.categoria_id=c.id_categoria AND p.activo=TRUE AND p.stock>0 GROUP BY c.id_categoria ORDER BY c.nombre"); return {"categories":cursor.fetchall()}
    finally: cursor.close()
@router.get("/products")
def listar_productos(category_id:int|None=None, connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        sql="SELECT p.id_producto AS id,p.categoria_id,p.nombre,p.marca,p.descripcion,p.precio,p.stock,p.imagen,c.nombre AS categoria FROM producto p JOIN categoria_producto c ON c.id_categoria=p.categoria_id WHERE p.activo=TRUE AND p.stock>0"; params=()
        if category_id is not None: sql += " AND p.categoria_id=%s"; params=(category_id,)
        cursor.execute(sql+" ORDER BY p.fecha_actualizacion DESC",params); return {"products":[serialize_media(row,"imagen") for row in cursor.fetchall()]}
    finally: cursor.close()
@router.get("/products/{product_id}")
def detalle_producto(product_id:int, connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT p.id_producto AS id,p.categoria_id,p.nombre,p.marca,p.descripcion,p.precio,p.stock,p.imagen,p.imagen_2,p.imagen_3,p.imagen_4,c.nombre AS categoria FROM producto p JOIN categoria_producto c ON c.id_categoria=p.categoria_id WHERE p.id_producto=%s AND p.activo=TRUE",(product_id,)); product=cursor.fetchone()
        if not product: raise HTTPException(status_code=404,detail="Producto no encontrado")
        return serialize_media(product,"imagen","imagen_2","imagen_3","imagen_4")
    finally: cursor.close()
