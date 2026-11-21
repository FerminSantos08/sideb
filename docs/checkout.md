# Compra móvil y PayPal directo

El pago móvil utiliza Flutter → FastAPI → PayPal Orders v2. No abre páginas PHP,
no requiere Apache/PHP-FPM ni utiliza cookies o tickets de la web para pagar.
La web conserva su integración y ambos proyectos comparten el registro MySQL de
pedidos, detalles e inventario.

## Recorrido

1. Tienda → carrito → dirección → resumen calculado por FastAPI.
2. FastAPI crea el pedido con un `request_id` UUID: repetir la solicitud no duplica
   el pedido. Se vacía el carrito, conservando el detalle del pedido pendiente.
3. «Pagar con PayPal» solicita una orden a FastAPI. Las credenciales están solo en
   el entorno de la API. Se abre la aprobación oficial HTTPS de PayPal.
4. PayPal vuelve a `/payments/paypal/return` o `/payments/paypal/cancel` en la API.
   Una página mínima permite abrir `sideb://payment/result` para regresar a la app.
5. Al abrir el pedido, volver del navegador o pulsar «Actualizar estado», Flutter
   solicita `payment-confirm`. FastAPI consulta PayPal; captura únicamente una
   orden aprobada y verifica identidad, importe MXN y captura completada.
6. Bajo bloqueo de pedido/productos, registra el pago y descuenta inventario una
   sola vez. Reintentos y respuestas perdidas se recuperan con ids estables y una
   consulta independiente a PayPal. Volver a la app nunca demuestra un pago.

Cancelar o cerrar el navegador no marca el pedido como pagado ni lo elimina.
El inventario se comprueba antes del pago y la captura; no se reserva al crear
un pedido pendiente. Si cambia, se informa al usuario para revisar el pedido.
Los importes son del servidor, incluyendo el envío de $99 MXN.

## Configuración independiente de la API

En `API/.env` (no en Flutter ni en el repositorio):

```dotenv
PAYPAL_MODE=sandbox
PAYPAL_CLIENT_ID=credencial_de_la_app_paypal
PAYPAL_CLIENT_SECRET=secreto_de_la_misma_app_paypal
# Para despliegue público, incluir HTTPS y cualquier prefijo:
PUBLIC_API_URL=https://api.ejemplo.com
# Opcional en LAN; necesario para recibir notificaciones públicas verificadas:
PAYPAL_WEBHOOK_ID=id_del_webhook_de_la_misma_app_paypal
```

Sandbox y Live usan credenciales distintas. Reiniciar FastAPI después de cambiar
el entorno. En desarrollo LAN, sin `PUBLIC_API_URL`, el retorno utiliza el host y
puerto usados por Flutter (por ejemplo `http://192.168.3.22:8000`). El teléfono debe
poder acceder a esa dirección. Live requiere HTTPS.

Para webhooks, publicar la API mediante HTTPS y registrar en PayPal la URL
`https://api.ejemplo.com/payments/paypal/webhook` para `PAYMENT.CAPTURE.COMPLETED`.
El servidor verifica la firma con PayPal, consulta de nuevo la orden y reconcilia
sin volver a capturar. Los eventos repetidos no vuelven a descontar stock. En LAN
sin webhook público, la confirmación autenticada al volver/abrir el pedido sigue
funcionando. El webhook no se registra automáticamente.

No se requiere una migración adicional para el pago directo. Se reutilizan
`pedido.paypal_order_id`, `paypal_capture_id`, `fecha_pago` y las tablas de pedidos.
`mobile_checkout_request` conserva la idempotencia del checkout. La tabla antigua
`mobile_payment_session` queda disponible para la web, sin uso en el flujo móvil.

## Endpoints

| Método | Ruta | Uso |
| --- | --- | --- |
| GET | `/checkout/addresses` | Direcciones autenticadas |
| POST | `/checkout/quote` | Resumen con `address_id` o `address` |
| POST | `/orders` | Crear con dirección, UUID y `expected_total` |
| GET | `/orders` | Historial del usuario |
| GET | `/orders/{id}` | Estado y detalle propios |
| POST | `/orders/{id}/payment-session` | Crear/reutilizar orden y enlace oficial PayPal |
| POST | `/orders/{id}/payment-confirm` | Consultar y capturar aprobación verificada |
| GET | `/payments/paypal/return` | Volver a la app; no modifica pedidos |
| GET | `/payments/paypal/cancel` | Volver tras cancelar; no modifica pedidos |
| POST | `/payments/paypal/webhook` | Firma verificada y reconciliación de captura |

## Validación

`API/tests/test_payments.py` usa PayPal simulado y tablas temporales MySQL para
probar permisos, importes, inventario, captura, recuperación y firmas de webhook.
No realiza cargos. `test/checkout_test.dart` comprueba que abrir o volver del
navegador no implica pago, y que la app consulta la confirmación del servidor.

Se comprobó además la creación real de una orden Sandbox y su URL de aprobación
con un pedido temporal: sin aprobarla ni capturarla. La aprobación final con una
cuenta compradora Sandbox se prueba manualmente desde el teléfono.
