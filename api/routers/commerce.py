from fastapi import APIRouter, Depends, HTTPException, status
from app.core.database import get_db
from app.dependencies import current_user
from app.schemas import CartItemCreate, CartItemUpdate, WishlistItemCreate
from app.utils import serialize_media

router = APIRouter(tags=["Comercio"])

_PRODUCT = """SELECT p.id_producto AS id,p.nombre,p.marca,p.descripcion,p.precio,p.stock,p.imagen,c.nombre AS categoria
FROM producto p JOIN categoria_producto c ON c.id_categoria=p.categoria_id"""

def _available_product(cursor, product_id):
    cursor.execute(_PRODUCT + " WHERE p.id_producto=%s AND p.activo=TRUE", (product_id,))
    product = cursor.fetchone()
    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return serialize_media(product, "imagen")

@router.get("/cart")
def get_cart(user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("""SELECT ci.cantidad,p.id_producto AS id,p.nombre,p.marca,p.descripcion,p.precio,p.stock,p.imagen,c.nombre AS categoria
        FROM carrito_item ci JOIN producto p ON p.id_producto=ci.producto_id
        JOIN categoria_producto c ON c.id_categoria=p.categoria_id
        WHERE ci.usr_id=%s ORDER BY ci.fecha_agregado DESC""", (user["id_usr"],))
        return {"items": [serialize_media(row, "imagen") for row in cursor.fetchall()]}
    finally:
        cursor.close()

@router.post("/cart/items", status_code=status.HTTP_201_CREATED)
def add_cart_item(body: CartItemCreate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        product = _available_product(cursor, body.product_id)
        if product["stock"] < body.quantity:
            raise HTTPException(status_code=409, detail="Stock insuficiente")
        cursor.execute("INSERT INTO carrito_item (usr_id,producto_id,cantidad) VALUES (%s,%s,%s) ON DUPLICATE KEY UPDATE cantidad=LEAST(cantidad + VALUES(cantidad), %s)", (user["id_usr"], body.product_id, body.quantity, product["stock"]))
        connection.commit()
        return {"product": product, "quantity": min(body.quantity, product["stock"]), "message": "Agregado al carrito"}
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()

@router.put("/cart/items/{product_id}")
def update_cart_item(product_id: int, body: CartItemUpdate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        product = _available_product(cursor, product_id)
        if body.quantity > product["stock"]:
            raise HTTPException(status_code=409, detail="Stock insuficiente")
        cursor.execute("UPDATE carrito_item SET cantidad=%s WHERE usr_id=%s AND producto_id=%s", (body.quantity, user["id_usr"], product_id))
        if not cursor.rowcount: raise HTTPException(status_code=404, detail="Producto no está en el carrito")
        connection.commit(); return {"product_id": product_id, "quantity": body.quantity}
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()

@router.delete("/cart/items/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_cart_item(product_id: int, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor()
    try:
        cursor.execute("DELETE FROM carrito_item WHERE usr_id=%s AND producto_id=%s", (user["id_usr"], product_id)); connection.commit()
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()

@router.get("/wishlist")
def get_wishlist(user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT producto_id FROM wishlist_item WHERE usr_id=%s',(user['id_usr'],))
        ids=[row['producto_id'] for row in cursor.fetchall()]
        cursor.execute(_PRODUCT + " JOIN wishlist_item wi ON wi.producto_id=p.id_producto WHERE wi.usr_id=%s AND p.activo=TRUE ORDER BY wi.fecha_guardado DESC", (user["id_usr"],))
        return {"items": [serialize_media(row, "imagen") for row in cursor.fetchall()],"saved_ids":ids}
    finally: cursor.close()

@router.post("/wishlist/items", status_code=status.HTTP_201_CREATED)
def add_wishlist_item(body: WishlistItemCreate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        product = _available_product(cursor, body.product_id)
        cursor.execute("INSERT IGNORE INTO wishlist_item (usr_id,producto_id) VALUES (%s,%s)", (user["id_usr"], body.product_id)); connection.commit()
        return {"product": product, "message": "Guardado en lista de deseos"}
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()

@router.delete("/wishlist/items/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_wishlist_item(product_id: int, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor()
    try:
        cursor.execute("DELETE FROM wishlist_item WHERE usr_id=%s AND producto_id=%s", (user["id_usr"], product_id)); connection.commit()
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()
