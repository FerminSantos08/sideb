# Guardados y administración editorial

## En la app

- El marcador de la barra superior del artículo guarda o quita la publicación.
  Si hace falta sesión, abre el login y retoma la acción al volver.
- Perfil → Publicaciones guardadas permite abrir artículos o quitar marcadores.
- Perfil → Mis publicaciones está disponible para los roles editoriales.
  Ofrece filtros por estado y acceso al editor de publicaciones existentes.
- El editor reutiliza el formulario de creación, precarga texto/HTML y relaciones,
  conserva los campos ante un error y actualiza su revisión después de guardar.
- Los estados son borrador, revisión, publicado y archivado. Archivar oculta el
  artículo del catálogo público; no borra sus comentarios, reacciones o marcadores.
- La edición móvil conserva el slug y permite elegir o sustituir la portada con
  una vista previa local antes de guardar. No elimina físicamente artículos.

## Guardado compartido con la web

Se utiliza `guardado_publicacion`, sin crear una biblioteca paralela ni una nueva
migración. Todos los endpoints requieren autenticación:

| Método | Ruta | Comportamiento |
| --- | --- | --- |
| GET | `/library/posts` | Artículos públicos guardados y `saved_ids` del usuario |
| PUT | `/library/posts/{id}` | Guardar, idempotente; exige publicación visible |
| DELETE | `/library/posts/{id}` | Quitar solo el marcador del usuario, idempotente |

Un artículo retirado o con fecha futura no se expone en la biblioteca móvil.
El marcador se conserva en la base y reaparece si vuelve a ser público.

## Administración

| Método | Ruta | Comportamiento |
| --- | --- | --- |
| GET | `/editorial/posts` | Propias para roles 2/4; todas para productor ejecutivo 3 |
| GET | `/editorial/posts/{id}` | Contenido, relaciones y revisión para editar |
| PUT | `/editorial/posts/{id}` | Actualizar título, descripción, contenido, etiquetas, relaciones y estado |

El permiso se comprueba en el servidor: solo el autor o el productor ejecutivo
pueden consultar el editor y modificar el artículo. Un Listener no puede acceder.
La identidad del autor no se acepta en el cuerpo de actualización.

`revision` es un SHA-256 de los campos editables, propietario, fecha de publicación
actual y relaciones ordenadas. La actualización bloquea el registro y compara la
revisión antes de escribir. Si web u otra sesión lo cambió, responde 409 sin
sobrescribir. El formulario conserva el texto para copiarlo antes de reabrir.

El HTML pasa por el saneamiento editorial existente y se validan artistas/álbumes.
Al publicar se asigna fecha si no existía; al pasar a un estado no público se
limpia, igual que en la web.

## Comprobación

- API: `pytest tests/test_library_editorial.py` usa tablas temporales de MySQL;
  no modifica artículos ni marcadores reales.
- Flutter: `flutter test test/library_editorial_test.dart` cubre persistencia del
  marcador, errores, precarga del editor, revisiones y control de acceso visible.
- El despliegue requiere reiniciar la API para registrar los dos routers nuevos.

## Portadas y lista de deseos

`POST /editorial/covers` recibe JPG, PNG o WebP de hasta 5 MB, verifica la imagen,
la convierte a WebP (máximo 1920 px) y entrega un token privado de una hora.
Crear o editar incluye `cover_token`: la portada y el texto se vinculan en la
misma transacción. Un reintento idéntico con ese token no duplica la publicación.
Aplicar `API/migrations/2026_11_17_editorial_covers.sql` antes del despliegue.

Perfil → Lista de deseos comparte `wishlist_item` con la web. El corazón del
producto consulta el estado del servidor; la lista permite abrir, quitar y pasar
al carrito productos disponibles. Los productos inactivos no se exponen.

La contraseña conserva únicamente el cambio autenticado con contraseña actual.
No se añade recuperación por correo.
