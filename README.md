# SIDE B Mobile

SIDE B reúne una revista musical, un catálogo de artistas y una tienda en una app para Android. Desde Inicio puedes descubrir artículos, explorar discografías y encontrar productos relacionados con la música. La app y la web comparten publicaciones guardadas, listas de deseos e historial de pedidos.

## Qué hace SIDE B

- **Editorial.** Artículos, publicaciones guardadas, comentarios y reacciones. Los usuarios autorizados pueden gestionar borradores, portadas, revisiones y publicaciones.
- **Artistas.** Perfiles con biografía, discografía y artículos relacionados.
- **Tienda.** Catálogo por categorías, fichas con galería y disponibilidad, productos relacionados, lista de deseos y carrito.
- **Cuenta.** Perfil, direcciones, historial de pedidos y selector de tema claro u oscuro.
- **Compras.** La API calcula el pedido y usa PayPal Sandbox para el pago. La confirmación se verifica en el servidor.

## Código en este repositorio

| Carpeta | Contenido |
| --- | --- |
| [api/](api/README.md) | API FastAPI, configuración de ejemplo, migraciones y pruebas. |
| [database/](database/) | Esquema MySQL y script de exportación. |
| [lib/](lib/) | Punto de entrada de Flutter, tema y componentes compartidos de interfaz. |
| [docs/](docs/) | Flujos de compra, publicaciones guardadas y reacciones. |

Esta versión incluye una selección del código Flutter. Para compilar la app y ejecutar sus pruebas se necesitan `SideBApp` y los módulos móviles completos.

## API y base de datos

1. Crea una base MySQL vacía e importa el [esquema](database/schema.sql). Contiene la estructura de las tablas y las migraciones aplicadas, sin registros.
2. Configura `api/.env` a partir de [api/.env.example](api/.env.example).
3. Sigue las [instrucciones de la API](api/README.md) para instalar las dependencias, levantar el servicio y ejecutar sus pruebas.

Para importar el esquema desde la raíz del repositorio:

```bash
mysql -u USUARIO -p BASE_VACIA < database/schema.sql
```

## Autoría y derechos

Proyecto de Fermin Santos Conde. Consulta [AUTHORS](AUTHORS) para los créditos y [COPYRIGHT](COPYRIGHT) para el aviso de derechos. Todos los derechos reservados.
