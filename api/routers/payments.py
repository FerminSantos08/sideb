"""Mobile payments use FastAPI and PayPal directly, without PHP or Apache."""
import os
import re
from decimal import Decimal, InvalidOperation
from urllib.parse import urlsplit
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from app.core.database import get_db
from app.dependencies import current_user
from app.paypal import get_paypal
from routers.checkout import order_data, PAID_STATES

router = APIRouter(tags=['PayPal móvil'])


def locked_order(cursor, order_id, user_id):
    cursor.execute('SELECT * FROM pedido WHERE id_pedido=%s AND usr_id=%s FOR UPDATE', (order_id, user_id))
    row = cursor.fetchone()
    if not row: raise HTTPException(404, 'Pedido no encontrado')
    return row


def paypal_path(order):
    value = order.get('paypal_order_id') or ''
    if not re.fullmatch(r'[A-Za-z0-9-]{1,64}', value):
        raise HTTPException(409, 'El pedido no tiene una orden válida de PayPal.')
    return '/v2/checkout/orders/' + value


def validate_total(order, remote, completed=False):
    units = remote.get('purchase_units', [])
    if remote.get('id') != order['paypal_order_id'] or len(units) != 1:
        raise HTTPException(409, 'La orden de PayPal no coincide con el pedido.')
    unit = units[0]
    try:
        amount = unit.get('amount', {})
        if (unit.get('custom_id') != str(order['id_pedido']) or amount.get('currency_code') != 'MXN'
                or Decimal(amount.get('value', 'NaN')) != order['total']):
            raise ValueError()
        if completed:
            captures = unit.get('payments', {}).get('captures', [])
            if remote.get('status') != 'COMPLETED' or len(captures) != 1:
                raise ValueError()
            capture = captures[0]
            if (capture.get('status') != 'COMPLETED' or not capture.get('id')
                    or capture.get('amount', {}).get('currency_code') != 'MXN'
                    or Decimal(capture.get('amount', {}).get('value', 'NaN')) != order['total']):
                raise ValueError()
            return capture['id']
    except (ValueError, InvalidOperation, TypeError):
        raise HTTPException(409, 'PayPal no confirmó el importe y la moneda esperados.')


def stock_items(cursor, order_id):
    cursor.execute('''SELECT d.producto_id,d.cantidad,p.stock,p.activo FROM pedido_detalle d
        LEFT JOIN producto p ON p.id_producto=d.producto_id WHERE d.pedido_id=%s
        ORDER BY d.producto_id FOR UPDATE''', (order_id,))
    items = cursor.fetchall()
    if not items or any(not item['activo'] or item['cantidad'] < 1 or item['stock'] < item['cantidad'] for item in items):
        raise HTTPException(409, 'El inventario cambió. Contacta a SIDE B para revisar el pedido antes de continuar.')
    return items


def settle(cursor, order, remote, items):
    capture_id = validate_total(order, remote, completed=True)
    for item in items:
        cursor.execute('UPDATE producto SET stock=stock-%s WHERE id_producto=%s AND stock>=%s',
                       (item['cantidad'], item['producto_id'], item['cantidad']))
        if cursor.rowcount != 1: raise HTTPException(409, 'No pudimos confirmar el inventario.')
    cursor.execute("UPDATE pedido SET estado='pagado',paypal_capture_id=%s,fecha_pago=NOW() WHERE id_pedido=%s AND estado='pendiente'",
                   (capture_id, order['id_pedido']))
    if cursor.rowcount != 1: raise HTTPException(409, 'No pudimos registrar el pago.')


def reconcile(connection, order_id, user_id, paypal, allow_capture=True):
    cursor = connection.cursor(dictionary=True)
    try:
        order = locked_order(cursor, order_id, user_id)
        if order['estado'] in PAID_STATES and order['paypal_capture_id']:
            result = order_data(cursor, order_id, user_id); connection.commit(); return result
        if order['estado'] != 'pendiente':
            raise HTTPException(409, 'Este pedido ya no tiene un pago pendiente.')
        if not order['paypal_order_id']:
            result = order_data(cursor, order_id, user_id); connection.commit(); return result
        path = paypal_path(order)
        remote = paypal.call('GET', path)
        validate_total(order, remote)
        status = remote.get('status')
        if status not in {'APPROVED', 'COMPLETED'} or (status == 'APPROVED' and not allow_capture):
            result = order_data(cursor, order_id, user_id); connection.commit(); return result
        items = stock_items(cursor, order_id)
        if status == 'APPROVED':
            try:
                paypal.call('POST', path + '/capture', request_id='sideb-capture-' + str(order_id))
                remote = paypal.call('GET', path)
            except HTTPException:
                # Recover a capture accepted by PayPal whose response was lost.
                remote = paypal.call('GET', path)
                if remote.get('status') != 'COMPLETED': raise HTTPException(502, 'El pago sigue sin confirmar. Puedes verificarlo otra vez.')
        settle(cursor, order, remote, items)
        result = order_data(cursor, order_id, user_id)
        connection.commit()
        return result
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()


@router.post('/orders/{order_id}/payment-session')
def payment_session(order_id: int, request: Request, user=Depends(current_user), connection=Depends(get_db), paypal=Depends(get_paypal)):
    cursor = connection.cursor(dictionary=True)
    try:
        order = locked_order(cursor, order_id, user['id_usr'])
        if order['estado'] != 'pendiente': raise HTTPException(409, 'Este pedido ya no tiene un pago pendiente.')
        stock_items(cursor, order_id)
        if order['paypal_order_id']:
            remote = paypal.call('GET', paypal_path(order))
            validate_total(order, remote)
        else:
            base = os.getenv('PUBLIC_API_URL', '').rstrip('/') or str(request.base_url).rstrip('/')
            parsed_base = urlsplit(base)
            if (parsed_base.scheme not in {'http', 'https'} or not parsed_base.hostname or parsed_base.username
                    or parsed_base.query or parsed_base.fragment or (paypal.mode == 'live' and parsed_base.scheme != 'https')):
                raise HTTPException(503, 'Configura PUBLIC_API_URL con la URL pública de la API (HTTPS en Live).')
            remote = paypal.call('POST', '/v2/checkout/orders', {
                'intent': 'CAPTURE',
                'purchase_units': [{'reference_id': 'sideb-' + str(order_id), 'custom_id': str(order_id),
                    'amount': {'currency_code': 'MXN', 'value': format(order['total'], '.2f')}}],
                'payment_source': {'paypal': {'experience_context': {'brand_name': 'SIDE B',
                    'shipping_preference': 'NO_SHIPPING', 'user_action': 'PAY_NOW',
                    'return_url': base + '/payments/paypal/return', 'cancel_url': base + '/payments/paypal/cancel'}}},
            }, request_id='sideb-create-' + str(order_id))
            if not re.fullmatch(r'[A-Za-z0-9-]{1,64}', remote.get('id', '')):
                raise HTTPException(502, 'PayPal no devolvió una orden válida.')
            cursor.execute('UPDATE pedido SET paypal_order_id=%s WHERE id_pedido=%s', (remote['id'], order_id))
        # Persist the remote ID before reporting an already approved/captured order.
        connection.commit()
        if remote.get('status') in {'APPROVED', 'COMPLETED'}:
            return {'url': str(request.base_url).rstrip('/') + '/payments/paypal/return', 'requires_confirmation': True}
        expected = 'www.paypal.com' if paypal.mode == 'live' else 'www.sandbox.paypal.com'
        link = next((x.get('href', '') for x in remote.get('links', []) if x.get('rel') in {'payer-action', 'approve'}), '')
        parsed = urlsplit(link)
        if parsed.scheme != 'https' or parsed.hostname != expected or parsed.username or parsed.port not in (None, 443):
            raise HTTPException(502, 'PayPal no devolvió un enlace de aprobación válido.')
        return {'url': link}
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()


@router.post('/orders/{order_id}/payment-confirm')
def confirm(order_id: int, user=Depends(current_user), connection=Depends(get_db), paypal=Depends(get_paypal)):
    return reconcile(connection, order_id, user['id_usr'], paypal)


def return_page(cancelled=False):
    message = 'Puedes retomar el pago desde tu pedido.' if cancelled else 'Vuelve a SIDE B para verificar el pago con PayPal.'
    return HTMLResponse('''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SIDE B · PayPal</title></head><body style="background:#f4f0e6;color:#292a27;font:18px system-ui;padding:40px;max-width:560px;margin:auto"><h1>SIDE B</h1><p>''' + message + '''</p><a href="sideb://payment/result" style="color:#606950">VOLVER A SIDE B</a></body></html>''', headers={'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer', 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'"})


@router.get('/payments/paypal/return', response_class=HTMLResponse)
def returned(): return return_page()


@router.get('/payments/paypal/cancel', response_class=HTMLResponse)
def cancelled(): return return_page(True)


@router.post('/payments/paypal/webhook')
async def webhook(request: Request, connection=Depends(get_db), paypal=Depends(get_paypal)):
    from starlette.concurrency import run_in_threadpool
    webhook_id = os.getenv('PAYPAL_WEBHOOK_ID', '')
    if not webhook_id: raise HTTPException(503, 'Webhook de PayPal no configurado.')
    body = bytearray()
    async for chunk in request.stream():
        if len(body) + len(chunk) > 262144: raise HTTPException(413, 'Evento demasiado grande.')
        body.extend(chunk)
    import json
    try: event = json.loads(body)
    except ValueError: raise HTTPException(400, 'Evento no válido.')
    if not isinstance(event, dict): raise HTTPException(400, 'Evento no válido.')
    verification = {'webhook_id': webhook_id, 'webhook_event': event}
    for key in ('auth_algo', 'cert_url', 'transmission_id', 'transmission_sig', 'transmission_time'):
        value = request.headers.get('paypal-' + key.replace('_', '-'))
        if not value: raise HTTPException(400, 'Firma incompleta.')
        verification[key] = value
    result = await run_in_threadpool(paypal.call, 'POST', '/v1/notifications/verify-webhook-signature', verification)
    if result.get('verification_status') != 'SUCCESS': raise HTTPException(400, 'Firma no válida.')
    if event.get('event_type') != 'PAYMENT.CAPTURE.COMPLETED': return {'received': True}
    remote_id = event.get('resource', {}).get('supplementary_data', {}).get('related_ids', {}).get('order_id')
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT id_pedido,usr_id FROM pedido WHERE paypal_order_id=%s', (remote_id,))
        order = cursor.fetchone()
    finally: cursor.close()
    connection.rollback()
    if order:
        await run_in_threadpool(reconcile, connection, order['id_pedido'], order['usr_id'], paypal, False)
    return {'received': True}
