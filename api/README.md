# SIDE B API

API REST de FastAPI para SIDE B Mobile. Comparte MySQL con la web PHP/PDO; no modifica el proyecto Flutter ni reemplaza las sesiones PHP.

## Inicio

Requiere Python 3.14, MySQL accesible y [uv](https://docs.astral.sh/uv/). Instala las dependencias con `uv sync`, copia `.env.example` a `.env` y completa las variables. `JWT_SECRET` debe ser un valor aleatorio de al menos 32 caracteres y no debe subirse a Git.

```powershell
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger queda en `http://127.0.0.1:8000/docs` y el contrato OpenAPI en `/openapi.json`.

## Configuración

`DB_*` apunta a la misma base `side_b` que usa PHP. `MEDIA_BASE_URL` debe ser la URL de Apache visible para el dispositivo, por ejemplo `http://192.168.3.15/SIDE_B`; así las rutas de imágenes almacenadas en MySQL se convierten en URLs útiles, no rutas de Windows. Flutter nativo no requiere CORS; para un cliente web configure sus orígenes concretos en `CORS_ORIGINS`.

Para Android use la IPv4 privada actual del equipo, `192.168.3.15`, no `0.0.0.0`: `http://192.168.3.15:8000`. Si Windows bloquea el acceso, cree una regla de entrada TCP para el puerto 8000 limitada al perfil **Privado** y a la subred de desarrollo; no desactive el firewall ni exponga MySQL.

## Endpoints disponibles

| Módulo web | API | Estado |
|---|---|---|
| Editorial | `GET /posts`, `GET /posts/{id}`, `GET /posts/slug/{slug}`, comentarios | Implementado |
| Artistas y álbumes | `GET /artists`, `GET /artists/{id}` | Implementado |
| Catálogo | `GET /products`, `GET /products/{id}`, `GET /categories` | Implementado |
| Usuarios | `POST /auth/login`, `POST /auth/register`, `GET /auth/me` | Implementado |
| Carrito | — | Pendiente: la página PHP es una maqueta local, no consulta `carrito_item` |
| Pedidos | — | Pendiente: sólo existe administración web; no hay checkout público funcional |

Las rutas protegidas usan `Authorization: Bearer <token>`. El login verifica hashes bcrypt compatibles con `password_hash()` de PHP. El registro crea únicamente cuentas Listener, igual que la web. No se han creado rutas administrativas: requieren diseñar y verificar las reglas de autorización de cada mutación antes de exponerlas.

Ejemplo:

```http
POST /auth/login
Content-Type: application/json

{"email":"persona@ejemplo.com","password":"contraseña"}
```

```http
POST /posts/1/comments
Authorization: Bearer <token>
Content-Type: application/json

{"comentario":"Excelente publicación"}
```

## Auditoría y pendientes

| Módulo | Estado web | Estado API | Acción necesaria |
|---|---|---|---|
| Editorial | Publicaciones y comentarios funcionales; reacciones/guardados anunciados como pendientes | Listado, detalle y comentarios | No implementar reacciones ni guardados |
| Artistas | Listado y detalle con álbumes | Listado y detalle | Ninguna |
| Álbumes | Se muestran dentro de artista; administración existente | Incluidos en detalle de artista | No hay listado independiente en web |
| Productos | Listado/detalle funcionales; sin datos activos actualmente | Lectura implementada | Mantener catálogo desde Backstage |
| Carrito | Maqueta con datos estáticos | No implementado | Conectar la web a `carrito_item` primero |
| Usuarios | Registro/login/perfil; roles 1 Listener, 2 Artist, 3 Executive Producer, 4 Editor | Login, registro, perfil | Diseñar API administrativa antes de exponerla |

La auditoría también detectó que Backstage permite administrar productos, categorías, artistas, álbumes, pedidos y usuarios; esas mutaciones no se publicaron en la API para evitar abrir operaciones administrativas sin una política de permisos completa. Comunidad, mensajería privada y “El otro lado del vinilo” no se implementaron.

## Pruebas

Las pruebas son de lectura y no alteran datos:

```powershell
$env:JWT_SECRET='un-secreto-de-prueba-de-al-menos-32-caracteres'
uv run pytest
```

Cubren salud, OpenAPI, conexión a los listados reales, recursos inexistentes, autenticación requerida y validación de entrada. Las escrituras (registro y comentarios) se deben ejecutar sólo contra una base aislada de pruebas.

## Recuperación en Fedora (12 de noviembre de 2026)

Esta carpeta se recuperó del backend incluido en el respaldo de SIDE B Mobile.
La copia incompleta previa se conserva en `~/Respaldos/Side-B-API-incompleta-*`.

Se usa Python 3.14: el conector MySQL recuperado falla al importar con Python
3.15 por una constante TLS retirada. Para preparar el entorno:

```bash
python3.14 -m venv .venv
.venv/bin/python -m pip install fastapi uvicorn mysql-connector-python python-dotenv bcrypt email-validator httpx pytest
.venv/bin/python -m pytest -q
.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Las credenciales de la BD y `JWT_SECRET` se configuran en `.env` (no versionado).
`UPLOADS_DIR=/var/www/html/side-b/uploads` permite servir imágenes en
`/media/uploads/`, sin depender de que Apache acepte conexiones desde el móvil.
Esa ruta solo permite extensiones de imágenes y no entrega los JSON de créditos.

Configura `MEDIA_BASE_URL` y `MEDIA_BASE_URLS` para incluir las direcciones con
las que se consulta la API, con el sufijo `/media`. Por ejemplo, el emulador
Android usa `http://10.0.2.2:8000/media`. La IP LAN del equipo puede cambiar.

La app móvil admite una dirección explícita:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Para un teléfono físico se necesita la IP LAN accesible de la computadora y
conectividad al puerto 8000. No se ha verificado todavía un dispositivo físico.


## PayPal móvil independiente de PHP

El checkout móvil se sirve desde FastAPI: `routers/payments.py` y `app/paypal.py`.
Requiere `PAYPAL_MODE`, `PAYPAL_CLIENT_ID` y `PAYPAL_CLIENT_SECRET` en el entorno de
la API; no se consulta el entorno de la web durante la ejecución. Para desplegar,
configurar `PUBLIC_API_URL` con HTTPS. El retorno/cancelación se sirve por la API.
`POST /orders/{id}/payment-confirm` consulta y captura solo aprobaciones válidas.
Para webhooks públicos, configurar `PAYPAL_WEBHOOK_ID` y registrar
`/payments/paypal/webhook` para `PAYMENT.CAPTURE.COMPLETED`. El pago móvil no
requiere Apache, PHP-FPM ni los endpoints de pago PHP. No hay migración adicional.
Ver el recorrido y configuración en `Mobile/docs/checkout.md` del proyecto.
