import hashlib
from urllib.parse import urlsplit, parse_qs
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from main import app
from app.core.database import get_db, get_db_connection
from app.dependencies import current_user


@pytest.fixture
def isolated_checkout():
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    original = app.dependency_overrides.copy()
    try:
        # All writes are isolated in connection-local temporary tables.
        for table in ('usuario','producto','direccion_usuario','carrito_item','pedido','pedido_detalle','mobile_checkout_request','mobile_payment_session'):
            cursor.execute('SHOW CREATE TABLE '+table)
            ddl=cursor.fetchone()['Create Table']
            ddl='\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('CONSTRAINT'))
            ddl=ddl.replace('CREATE TABLE','CREATE TEMPORARY TABLE',1).replace(',\n)','\n)')
            cursor.execute(ddl)
        cursor.execute("INSERT INTO usuario (id_usr,nom_usr,mail,pass,tip_usu) VALUES (501,'checkout-test','checkout@example.invalid','unused',1)")
        cursor.execute("INSERT INTO producto (id_producto,categoria_id,nombre,precio,stock,activo) VALUES (601,1,'Disco de prueba',399,3,TRUE)")
        cursor.execute("INSERT INTO direccion_usuario (id_direccion,usr_id,etiqueta,direccion,es_principal) VALUES (701,501,'Casa','Dirección aislada',TRUE)")
        cursor.execute('INSERT INTO carrito_item (usr_id,producto_id,cantidad) VALUES (501,601,2)')
        connection.commit()
        app.dependency_overrides[get_db]=lambda:connection
        app.dependency_overrides[current_user]=lambda:{'id_usr':501}
        yield TestClient(app),connection,cursor
    finally:
        app.dependency_overrides.clear();app.dependency_overrides.update(original)
        cursor.close();connection.close()


def payload(**kwargs):
    return {'address_id':701,'expected_total':'897.00','request_id':str(uuid4()),**kwargs}


def test_quote_uses_server_prices_and_owned_address(isolated_checkout):
    client,_,_=isolated_checkout
    response=client.post('/checkout/quote',json={'address_id':701})
    assert response.status_code==200,response.text
    data=response.json()
    assert float(data['subtotal'])==798
    assert float(data['shipping'])==99
    assert float(data['total'])==897
    assert data['address']=='Dirección aislada'
    assert client.post('/checkout/quote',json={'address_id':9999}).status_code==404
    assert client.post('/checkout/quote',json={'address':'   '}).status_code==422


def test_create_is_idempotent_and_recovers_after_cart_is_cleared(isolated_checkout):
    client,_,cursor=isolated_checkout
    body=payload()
    first=client.post('/orders',json=body)
    assert first.status_code==200,first.text
    second=client.post('/orders',json=body)
    assert second.json()['id']==first.json()['id']
    assert first.json()['paid'] is False
    cursor.execute('SELECT COUNT(*) AS n FROM pedido');assert cursor.fetchone()['n']==1
    cursor.execute('SELECT COUNT(*) AS n FROM carrito_item');assert cursor.fetchone()['n']==0
    cursor.execute('SELECT stock FROM producto WHERE id_producto=601');assert cursor.fetchone()['stock']==3
    assert client.get('/orders').json()['orders'][0]['id']==first.json()['id']


def test_price_or_stock_change_does_not_create_an_order_or_clear_cart(isolated_checkout):
    client,connection,cursor=isolated_checkout
    assert client.post('/orders',json=payload(expected_total='1.00')).status_code==409
    cursor.execute('SELECT COUNT(*) AS n FROM carrito_item');assert cursor.fetchone()['n']==1
    connection.rollback()
    cursor.execute('UPDATE producto SET stock=1 WHERE id_producto=601');connection.commit()
    assert client.post('/orders',json=payload()).status_code==409
    cursor.execute('SELECT COUNT(*) AS n FROM pedido');assert cursor.fetchone()['n']==0


def test_orders_and_payment_sessions_are_owner_scoped(isolated_checkout):
    client,_,cursor=isolated_checkout
    order=client.post('/orders',json=payload()).json()
    app.dependency_overrides[current_user]=lambda:{'id_usr':502}
    assert client.get(f"/orders/{order['id']}").status_code==404
    assert client.post(f"/orders/{order['id']}/payment-session").status_code==404
    assert client.get('/orders').json()=={'orders':[]}


def test_cancelled_or_paid_order_cannot_open_a_new_payment(isolated_checkout):
    client,connection,cursor=isolated_checkout
    order=client.post('/orders',json=payload()).json()
    cursor.execute("UPDATE pedido SET estado='cancelado' WHERE id_pedido=%s",(order['id'],));connection.commit()
    assert client.post(f"/orders/{order['id']}/payment-session").status_code==409


def test_checkout_requires_login(isolated_checkout):
    client,_,_=isolated_checkout
    del app.dependency_overrides[current_user]
    assert client.get('/checkout/addresses').status_code==401
    assert client.post('/checkout/quote',json={'address':'Prueba'}).status_code==401
    assert client.post('/orders',json=payload()).status_code==401
    assert client.get('/orders').status_code==401
