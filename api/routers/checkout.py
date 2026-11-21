"""Mobile checkout uses the shared order ledger; PayPal is handled by FastAPI."""
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from app.core.database import get_db
from app.dependencies import current_user
from app.utils import serialize_media

router = APIRouter(tags=['Compra y pedidos'])
SHIPPING = Decimal('99.00')
PAID_STATES = {'pagado', 'preparando', 'enviado', 'entregado'}


class Delivery(BaseModel):
    address_id: int | None = Field(default=None, gt=0)
    address: str | None = Field(default=None, max_length=255)

    @model_validator(mode='after')
    def require_address(self):
        if self.address_id is None and not (self.address or '').strip():
            raise ValueError('Selecciona o escribe una dirección de envío')
        return self


class OrderCreate(Delivery):
    request_id: UUID
    expected_total: Decimal = Field(gt=0, max_digits=12, decimal_places=2)


def cart(cursor, user_id, lock=False):
    cursor.execute('''SELECT ci.producto_id AS id,ci.cantidad AS quantity,
        p.nombre AS name,p.precio AS price,p.stock,p.activo AS active,p.imagen AS image
        FROM carrito_item ci JOIN producto p ON p.id_producto=ci.producto_id
        WHERE ci.usr_id=%s ORDER BY ci.producto_id''' + (' FOR UPDATE' if lock else ''), (user_id,))
    items = cursor.fetchall()
    if not items:
        raise HTTPException(409, 'Tu carrito está vacío')
    for item in items:
        if not item['active'] or item['quantity'] < 1 or item['quantity'] > item['stock']:
            raise HTTPException(409, 'El inventario cambió. Revisa los productos de tu carrito.')
        item['line_total'] = item['price'] * item['quantity']
        serialize_media(item, 'image')
    return items


def address(cursor, body, user_id):
    if body.address_id:
        cursor.execute('SELECT direccion FROM direccion_usuario WHERE id_direccion=%s AND usr_id=%s', (body.address_id, user_id))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(404, 'Dirección no encontrada')
        return row['direccion']
    return body.address.strip()


def quote_data(cursor, body, user_id, lock=False):
    destination = address(cursor, body, user_id)
    items = cart(cursor, user_id, lock)
    subtotal = sum((item['line_total'] for item in items), Decimal('0.00'))
    return {'address': destination, 'currency': 'MXN', 'items': items,
            'subtotal': subtotal, 'shipping': SHIPPING, 'discount': Decimal('0.00'),
            'tax': Decimal('0.00'), 'total': subtotal + SHIPPING}


def order_data(cursor, order_id, user_id, lock=False):
    cursor.execute('SELECT * FROM pedido WHERE id_pedido=%s AND usr_id=%s' + (' FOR UPDATE' if lock else ''), (order_id, user_id))
    row = cursor.fetchone()
    if not row:
        raise HTTPException(404, 'Pedido no encontrado')
    cursor.execute('''SELECT d.producto_id AS id,d.nombre_producto AS name,d.cantidad AS quantity,
        d.precio_unitario AS price,p.imagen AS image FROM pedido_detalle d
        LEFT JOIN producto p ON p.id_producto=d.producto_id WHERE d.pedido_id=%s ORDER BY d.id_detalle''', (order_id,))
    items = cursor.fetchall()
    for item in items:
        item['line_total'] = item['price'] * item['quantity']
        serialize_media(item, 'image')
    return {'id': row['id_pedido'], 'status': row['estado'], 'date': row['fecha'],
            'paid_at': row['fecha_pago'], 'paid': row['estado'] in PAID_STATES and bool(row['paypal_capture_id']),
            'address': row['direccion_envio'], 'currency': 'MXN', 'total': row['total'],
            'subtotal': row['subtotal'], 'shipping': row['envio'], 'discount': row['descuento'],
            'tax': row['impuestos'], 'items': items}


@router.get('/checkout/addresses')
def addresses(user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT id_direccion AS id,etiqueta AS label,direccion AS address,es_principal AS is_default FROM direccion_usuario WHERE usr_id=%s ORDER BY es_principal DESC,fecha_creacion DESC', (user['id_usr'],))
        return {'addresses': cursor.fetchall()}
    finally:
        cursor.close()


@router.post('/checkout/quote')
def quote(body: Delivery, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        return quote_data(cursor, body, user['id_usr'])
    finally:
        cursor.close()


@router.post('/orders')
def create_order(body: OrderCreate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        # Serializes mobile checkout attempts per account, including retries
        # after a lost response. The request id is scoped to the owner.
        cursor.execute('SELECT id_usr FROM usuario WHERE id_usr=%s FOR UPDATE', (user['id_usr'],))
        cursor.fetchone()
        cursor.execute('SELECT pedido_id FROM mobile_checkout_request WHERE usr_id=%s AND request_id=%s', (user['id_usr'], str(body.request_id)))
        previous = cursor.fetchone()
        if previous:
            result = order_data(cursor, previous['pedido_id'], user['id_usr'])
            connection.commit()
            return result
        data = quote_data(cursor, body, user['id_usr'], lock=True)
        if data['total'] != body.expected_total:
            raise HTTPException(409, 'El precio cambió. Actualiza el resumen antes de continuar.')
        cursor.execute('''INSERT INTO pedido (usr_id,estado,total,subtotal,envio,descuento,impuestos,direccion_envio)
            VALUES (%s,'pendiente',%s,%s,%s,0,0,%s)''',
            (user['id_usr'], data['total'], data['subtotal'], data['shipping'], data['address']))
        order_id = cursor.lastrowid
        cursor.executemany('INSERT INTO pedido_detalle (pedido_id,producto_id,nombre_producto,cantidad,precio_unitario) VALUES (%s,%s,%s,%s,%s)',
            [(order_id, item['id'], item['name'], item['quantity'], item['price']) for item in data['items']])
        cursor.execute('INSERT INTO mobile_checkout_request (usr_id,request_id,pedido_id) VALUES (%s,%s,%s)', (user['id_usr'], str(body.request_id), order_id))
        cursor.execute('DELETE FROM carrito_item WHERE usr_id=%s', (user['id_usr'],))
        result = order_data(cursor, order_id, user['id_usr'])
        connection.commit()
        return result
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


@router.get('/orders')
def orders(user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT id_pedido FROM pedido WHERE usr_id=%s ORDER BY fecha DESC,id_pedido DESC LIMIT 100', (user['id_usr'],))
        ids = [row['id_pedido'] for row in cursor.fetchall()]
        return {'orders': [order_data(cursor, id, user['id_usr']) for id in ids]}
    finally:
        cursor.close()


@router.get('/orders/{order_id}')
def get_order(order_id: int, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        return order_data(cursor, order_id, user['id_usr'])
    finally:
        cursor.close()
