from copy import deepcopy
import pytest
from fastapi import HTTPException
from app.paypal import get_paypal
from app.dependencies import current_user
from main import app
from test_checkout import isolated_checkout, payload

class FakePayPal:
    mode = 'sandbox'
    def __init__(self):
        self.remote = None
        self.creates = self.captures = 0
        self.lose_capture = False
        self.signature = 'SUCCESS'
    def call(self, method, path, payload=None, request_id=None):
        if path.endswith('verify-webhook-signature'):return {'verification_status':self.signature}
        if method == 'POST' and path == '/v2/checkout/orders':
            self.creates += 1
            assert request_id.startswith('sideb-create-')
            assert '.php' not in str(payload)
            self.remote = {'id':'PAYPAL-TEST','status':'PAYER_ACTION_REQUIRED','purchase_units':deepcopy(payload['purchase_units']),
                           'links':[{'rel':'payer-action','href':'https://www.sandbox.paypal.com/checkoutnow?token=PAYPAL-TEST'}]}
        elif path.endswith('/capture'):
            self.captures += 1
            assert request_id.startswith('sideb-capture-')
            self.remote['status']='COMPLETED'
            self.remote['purchase_units'][0]['payments']={'captures':[{'id':'CAPTURE-TEST','status':'COMPLETED','amount':deepcopy(self.remote['purchase_units'][0]['amount'])}]}
            if self.lose_capture:raise HTTPException(502,'Response lost')
        return deepcopy(self.remote)

@pytest.fixture
def payments(isolated_checkout):
    client,connection,cursor=isolated_checkout
    fake=FakePayPal();app.dependency_overrides[get_paypal]=lambda:fake
    order=client.post('/orders',json=payload()).json()
    return client,connection,cursor,fake,order['id']

def start(client,id):
    r=client.post(f'/orders/{id}/payment-session');assert r.status_code==200,r.text
    assert r.json()['url'].startswith('https://www.sandbox.paypal.com/')

def test_direct_approval_reuse_and_capture_are_idempotent(payments):
    client,c,q,fake,id=payments
    start(client,id);start(client,id);assert fake.creates==1
    assert client.post(f'/orders/{id}/payment-confirm').json()['paid'] is False
    assert fake.captures==0
    fake.remote['status']='APPROVED'
    result=client.post(f'/orders/{id}/payment-confirm');assert result.status_code==200,result.text
    assert result.json()['paid'] is True
    assert client.post(f'/orders/{id}/payment-confirm').json()['paid'] is True
    assert fake.captures==1
    q.execute('SELECT stock FROM producto WHERE id_producto=601');assert q.fetchone()['stock']==1;c.rollback()
    assert client.post(f'/orders/{id}/payment-session').status_code==409

def test_lost_capture_response_recovers_without_second_charge(payments):
    client,c,q,fake,id=payments;start(client,id)
    fake.remote['status']='APPROVED';fake.lose_capture=True
    assert client.post(f'/orders/{id}/payment-confirm').json()['paid'] is True
    assert fake.captures==1

def test_foreign_order_and_fake_return_cannot_pay(payments):
    client,c,q,fake,id=payments
    assert client.get('/payments/paypal/return?token=FORGED').status_code==200
    assert client.get('/payments/paypal/cancel').status_code==200
    assert client.get(f'/orders/{id}').json()['paid'] is False
    app.dependency_overrides[current_user]=lambda:{'id_usr':502}
    assert client.post(f'/orders/{id}/payment-session').status_code==404
    assert client.post(f'/orders/{id}/payment-confirm').status_code==404
    assert fake.creates==fake.captures==0

def test_stock_currency_total_and_order_identity_are_checked(payments):
    client,c,q,fake,id=payments;start(client,id);fake.remote['status']='APPROVED'
    unit=fake.remote['purchase_units'][0]
    for field,bad in [('currency_code','USD'),('value','1.00')]:
        original=unit['amount'][field];unit['amount'][field]=bad
        assert client.post(f'/orders/{id}/payment-confirm').status_code==409
        unit['amount'][field]=original
    unit['custom_id']='999999'
    assert client.post(f'/orders/{id}/payment-confirm').status_code==409
    unit['custom_id']=str(id)
    q.execute('UPDATE producto SET stock=0 WHERE id_producto=601');c.commit()
    assert client.post(f'/orders/{id}/payment-confirm').status_code==409
    assert fake.captures==0
    assert client.get(f'/orders/{id}').json()['paid'] is False

def test_invalid_completed_capture_does_not_change_inventory(payments):
    client,c,q,fake,id=payments;start(client,id)
    fake.remote['status']='COMPLETED'
    fake.remote['purchase_units'][0]['payments']={'captures':[{'id':'BAD','status':'PENDING','amount':{'currency_code':'MXN','value':'897.00'}}]}
    assert client.post(f'/orders/{id}/payment-confirm').status_code==409
    q.execute('SELECT stock FROM producto WHERE id_producto=601');assert q.fetchone()['stock']==3

def test_untrusted_approval_host_is_rejected(payments):
    client,c,q,fake,id=payments;start(client,id)
    fake.remote['links'][0]['href']='https://attacker.invalid/pay'
    assert client.post(f'/orders/{id}/payment-session').status_code==502

def test_webhook_requires_signature_and_reconciles_once(payments,monkeypatch):
    client,c,q,fake,id=payments;start(client,id)
    monkeypatch.setenv('PAYPAL_WEBHOOK_ID','HOOK-TEST')
    event={'event_type':'PAYMENT.CAPTURE.COMPLETED','resource':{'supplementary_data':{'related_ids':{'order_id':'PAYPAL-TEST'}}}}
    assert client.post('/payments/paypal/webhook',json=event).status_code==400
    headers={'paypal-'+key:'test' for key in ['auth-algo','cert-url','transmission-id','transmission-sig','transmission-time']}
    fake.signature='FAILURE'
    assert client.post('/payments/paypal/webhook',json=event,headers=headers).status_code==400
    fake.signature='SUCCESS';fake.remote['status']='APPROVED'
    fake.call('POST','/capture',request_id='sideb-capture-test');assert fake.captures==1
    assert client.post('/payments/paypal/webhook',json=event,headers=headers).status_code==200
    assert client.post('/payments/paypal/webhook',json=event,headers=headers).status_code==200
    assert fake.captures==1
    q.execute('SELECT stock FROM producto WHERE id_producto=601');assert q.fetchone()['stock']==1

def test_confirm_requires_login(payments):
    client,c,q,fake,id=payments
    del app.dependency_overrides[current_user]
    assert client.post(f'/orders/{id}/payment-confirm').status_code==401
