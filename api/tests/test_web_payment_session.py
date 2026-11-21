"""Optional local HTTP test. Only a disposable ticket is written; no order or charge."""
import hashlib
import http.cookiejar
import os
import secrets
import urllib.request
import urllib.error

import pytest
from app.core.database import get_db_connection


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None


@pytest.mark.skipif(os.getenv('RUN_WEB_PAYMENT_TESTS')!='1',reason='Requires local Apache and existing pending sandbox order')
def test_payment_ticket_is_single_use_and_does_not_grant_a_web_account():
    c=get_db_connection();q=c.cursor(dictionary=True)
    ticket=secrets.token_urlsafe(32);digest=hashlib.sha256(ticket.encode()).hexdigest()
    base=os.getenv('CHECKOUT_WEB_TEST_URL','http://localhost')
    client=urllib.request.build_opener(NoRedirect(),urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def request(path):
        try:
            response=client.open(base+path,timeout=5)
        except urllib.error.HTTPError as error:response=error
        with response:return response.status,response.headers,response.read().decode()
    try:
        q.execute("SELECT p.id_pedido,p.usr_id FROM pedido p JOIN usuario u ON u.id_usr=p.usr_id WHERE p.estado='pendiente' AND u.activo=TRUE LIMIT 1")
        row=q.fetchone()
        if not row:pytest.skip('No pending sandbox order exists')
        q.execute('INSERT INTO mobile_payment_session(token_hash,usr_id,pedido_id,expires_at) VALUES (%s,%s,%s,DATE_ADD(NOW(),INTERVAL 5 MINUTE))',(digest,row['usr_id'],row['id_pedido']));c.commit()
        status,headers,_=request('/mobile_checkout.php?ticket='+ticket)
        assert status==303
        assert headers['Location']==f"pago.php?pedido={row['id_pedido']}"
        status,_,body=request('/'+headers['Location'])
        assert status==200
        assert 'paypal-button-container' in body
        # The scoped payment cookie cannot access the full web profile/orders.
        status,headers,_=request('/pedidos.php')
        assert status in (302,303)
        assert 'login.php' in headers['Location']
        status,_,_=request('/mobile_checkout.php?ticket='+ticket)
        assert status==410
        status,_,body=request('/mobile_payment_result.php?pedido='+str(row['id_pedido']))
        assert status==200
        assert 'sideb://payment/result' in body
        assert 'Tu pago sigue pendiente' in body
    finally:
        q.execute('DELETE FROM mobile_payment_session WHERE token_hash=%s',(digest,));c.commit()
        q.close();c.close()
