"""PayPal Orders v2; credentials and capture stay on the API server."""
import base64
import json
import logging
import os
from urllib import request, error
from fastapi import HTTPException

log = logging.getLogger(__name__)

class PayPal:
    def __init__(self):
        mode = os.getenv('PAYPAL_MODE', 'sandbox').strip().lower()
        if mode not in {'sandbox', 'live'}:
            raise HTTPException(503, 'PAYPAL_MODE debe ser sandbox o live.')
        self.mode = mode
        self.base = 'https://api-m.paypal.com' if mode == 'live' else 'https://api-m.sandbox.paypal.com'
        self.client = os.getenv('PAYPAL_CLIENT_ID', '').strip()
        self.secret = os.getenv('PAYPAL_CLIENT_SECRET', '').strip()
        if not self.client or not self.secret:
            raise HTTPException(503, 'Configura las credenciales de PayPal en el servidor de la API.')
        self.token = None

    def _send(self, method, path, body, headers):
        req = request.Request(self.base + path, data=body, headers=headers, method=method)
        try:
            with request.urlopen(req, timeout=25) as response:
                return json.load(response)
        except error.HTTPError as exc:
            log.warning('PayPal request failed: HTTP %s path=%s', exc.code, path)
            if path == '/v1/oauth2/token':
                raise HTTPException(502, 'PayPal rechazó las credenciales de la API. Revisa Client ID, Secret y modo Sandbox/Live.') from exc
            raise HTTPException(502, 'PayPal no pudo completar la operación. Puedes volver a verificar el pedido.') from exc
        except (error.URLError, TimeoutError, OSError, ValueError) as exc:
            log.warning('PayPal connection failed: %s', type(exc).__name__)
            raise HTTPException(502, 'No pudimos conectar con PayPal. Reintenta desde tu pedido.') from exc

    def call(self, method, path, payload=None, request_id=None):
        if self.token is None:
            auth = base64.b64encode((self.client + ':' + self.secret).encode()).decode()
            result = self._send('POST', '/v1/oauth2/token', b'grant_type=client_credentials',
                                {'Authorization': 'Basic ' + auth, 'Content-Type': 'application/x-www-form-urlencoded'})
            self.token = result.get('access_token')
            if not self.token:
                raise HTTPException(502, 'PayPal no devolvió un token de autenticación.')
        headers = {'Authorization': 'Bearer ' + self.token, 'Content-Type': 'application/json', 'Accept': 'application/json', 'Prefer': 'return=representation'}
        if request_id: headers['PayPal-Request-Id'] = request_id
        body = json.dumps(payload).encode() if payload is not None else (b'{}' if method == 'POST' else None)
        return self._send(method, path, body, headers)


def get_paypal():
    return PayPal()
