# Reacciones de publicaciones

Activo en MySQL, FastAPI y SIDE B Mobile. La web muestra el mismo catálogo y
los conteos de la base central en un desplegable de lectura.

| Id estable | Nombre | Lucide | Color |
| --- | --- | --- | --- |
| `me_encanta` | Me encanta | `heart` | `#C16A60` |
| `temazo` | Temazo | `music-2` | `#858C77` |
| `lo_escucharia` | Lo escuché | `headphones` | `#B89B72` |
| `sorprendente` | Sorprendente | `sparkles` | `#A18BB6` |

Máximo 5 tipos. Los ids no se renombran una vez utilizados. El catálogo está
registrado en `API/routers/reactions.py` y en `tipo_reaccion` mediante la
migración `API/migrations/2026_11_15_post_reactions.sql`, ya aplicada al entorno
local. `REACTIONS_ENABLED=true` activa el servicio después de migrar.

## Interacción

- Barra fija Reaccionar, Comentar y Compartir en tarjetas y detalle.
- Una pulsación prolongada abre una cápsula horizontal; deslizar resalta una
  opción y soltar sobre ella confirma. Soltar fuera cancela. Un toque corto
  abre la misma cápsula para elegir con otro toque.
- Las zonas se miden desde los RenderBox reales de cada icono. La cápsula tiene
  tamaño y posición constantes durante el gesto; solo el icono activo se escala
  y eleva. La etiqueta flota anclada al icono.
- El scroll conserva el gesto si el desplazamiento comienza antes de la
  pulsación prolongada. El overlay se cierra al salir del widget, cambiar las
  métricas de pantalla o dejar la app.
- Comentar abre el artículo en la conversación. Compartir abre la hoja nativa
  de Android; en plataformas sin ese canal copia el enlace. `WEB_BASE_URL`
  permite configurar el sitio público sin cambiar la dirección de la API.
- Iconos Lucide con sus colores, contador por tipo y marca de selección.
- Una reacción por usuario y publicación: tocar la misma la quita, otra la sustituye.
- Lectura pública y escritura con sesión; la API obtiene el usuario del token.
- La selección se vuelve a consultar en la API al abrir la publicación.
- Los envíos no se duplican mientras están pendientes; un fallo no cambia la selección confirmada.
- Los totales de tarjetas vienen en `/posts` (`reactions_count`); el desglose se consulta al abrir el menú.
- La tabla `post_reactions` usa clave primaria `(blog_id, usr_id)` y referencia
  a `tipo_reaccion`, `blog` y `usuario`. Es independiente de reacciones de comentarios.

## API

| Método | Ruta | Respuesta |
| --- | --- | --- |
| GET | `/reactions/types` | `enabled`, `max_types`, `types` con id/label/symbol/color |
| GET | `/posts/{id}/reactions` | `enabled`, `total`, `counts` por id |
| GET | `/posts/{id}/reaction` | Sesión: `reaction_id` y alias `mi_reaccion`, o null |
| PUT | `/posts/{id}/reaction` | Sesión: `{ "reaction_id": "temazo" }`; reemplazo idempotente |
| DELETE | `/posts/{id}/reaction` | Sesión: 204, idempotente |

Las publicaciones deben estar publicadas y su fecha de publicación cumplida.
Los tipos desconocidos se rechazan con 422. Las rutas personales sin sesión
devuelven 401. Desactivado, el catálogo queda vacío y no se consulta la tabla
de votos; las escrituras con sesión válida devuelven 503.

## Verificación

`flutter test test/reactions_test.dart test/reactions_widget_test.dart`
comprueba el catálogo, el contrato y la interacción del selector.

En API: `RUN_MYSQL_REACTION_TESTS=1 .venv/bin/python -m pytest` incluye una
prueba de persistencia y múltiples usuarios que sombrea la tabla de votos con
una tabla temporal local a su conexión. No genera reacciones en publicaciones reales.
