# SIDE B Mobile

Aplicación Flutter para la plataforma editorial y tienda musical SIDE B.

## Autoría y uso académico

Proyecto de Fermin Santos. Esta copia se entrega para revisión y evaluación académica. Estado declarado por el autor: **registro en trámite**. Consulta el [aviso de derechos](COPYRIGHT) y el [archivo de autoría](AUTHORS).

## Implementado

- Navegación inferior flotante adaptable a teléfonos y tabletas.
- Inicio y Editorial conectados a publicaciones reales.
- Artículos con estructura editorial, etiquetas, estado y rol de autor.
- Publicaciones guardadas compartidas con la web: marcador en artículos y biblioteca en Perfil.
- Administración editorial por rol: listado, filtros y edición de publicaciones con borradores, revisión, publicación, archivo y protección contra cambios concurrentes.
- Comentarios en artículos: lectura pública y publicación con sesión iniciada, máximo 500 caracteres, actualización y reintento sin perder el borrador.
- Reacciones con cápsula Lucide gestual: mantener, deslizar y soltar para elegir; cuatro tipos, contadores y selección persistente. Barra fija Reaccionar, Comentar y Compartir.
- Catálogo de Artistas, perfiles, álbumes y publicaciones relacionadas.
- Catálogo de Tienda y detalle de producto con galería, precio y stock.
- Carrito y lista de deseos compartida con la web, con corazón persistente y acceso desde Perfil.
- Portadas editoriales: selección, vista previa y guardado junto con el artículo.
- Configuración de perfil, foto, direcciones y cambio básico de contraseña con contraseña actual.
- Compra móvil: envío, resumen calculado por API, pago PayPal sandbox directo mediante FastAPI y aprobación en navegador (sin PHP para el pago móvil), retorno a la app e historial de pedidos compartido con la web. Ver `docs/checkout.md`.
- Login, registro público Listener, token seguro, recuperación de sesión, logout y Perfil dinámico por rol.
- Splash Android en marfil, compatible con modo claro y oscuro; icono y nombre con identidad SIDE B.
- Tipografía incluida en el APK, imágenes sin sombreado, galería adaptable y estados de carga/error/vacío consistentes.
- Barra flotante conservada; botón Atrás vuelve a Inicio y el teclado dispone del espacio de edición.

## Requisitos

- Flutter con Dart `^3.13.7`.
- API SIDE B disponible en la URL de `lib/core/config/api_config.dart`.
- Migración `wishlist_item` aplicada en MySQL para lista de deseos.
- `JWT_SECRET` de al menos 32 caracteres configurado en FastAPI.

## Compilación y pruebas

Esta entrega académica incluye una copia parcial del código móvil. El archivo
`lib/main.dart` muestra el arranque de Flutter. La implementación de
`SideBApp` y los módulos funcionales quedan reservados durante la prórroga.
La compilación y las pruebas requieren esos archivos.

## API y esquema MySQL

El código de FastAPI está en [api/](api/README.md). Su configuración local
se guarda en `api/.env` a partir de `api/.env.example`.

Con MySQL local en ejecución y las dependencias de la API instaladas, genera
`database/schema.sql` desde el directorio `api/`:

```bash
uv run --locked python ../database/export_schema.py
```

El archivo contiene la estructura de las tablas, sin registros. Para cargarlo
en una base MySQL vacía creada previamente:

```bash
mysql -u USUARIO -p BASE_VACÍA < database/schema.sql
```

Ejecuta la importación desde la raíz del repositorio. Las migraciones de
`api/migrations/` sirven para actualizar bases anteriores. El esquema
exportado ya incluye las migraciones aplicadas en la base de origen.
