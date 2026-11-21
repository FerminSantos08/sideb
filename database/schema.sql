
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `album` (
  `id_album` int NOT NULL AUTO_INCREMENT,
  `artista_id` int NOT NULL,
  `titulo` varchar(150) NOT NULL,
  `fecha_lanzamiento` date DEFAULT NULL,
  `portada` varchar(255) DEFAULT NULL,
  `tipo` enum('album','ep','sencillo') NOT NULL DEFAULT 'album',
  PRIMARY KEY (`id_album`),
  KEY `idx_album_artista` (`artista_id`),
  KEY `idx_album_lanzamiento` (`fecha_lanzamiento`),
  CONSTRAINT `fk_album_artista` FOREIGN KEY (`artista_id`) REFERENCES `artista` (`id_artista`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `artista` (
  `id_artista` int NOT NULL AUTO_INCREMENT,
  `usuario_id` int DEFAULT NULL,
  `nombre` varchar(150) NOT NULL,
  `biografia` text,
  `imagen` varchar(255) DEFAULT NULL,
  `genero` varchar(100) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id_artista`),
  UNIQUE KEY `usuario_id` (`usuario_id`),
  KEY `idx_artista_nombre` (`nombre`),
  CONSTRAINT `fk_artista_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`id_usr`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blog` (
  `id_blog` int NOT NULL AUTO_INCREMENT,
  `titulo` varchar(200) NOT NULL,
  `desc` varchar(500) DEFAULT NULL,
  `img` varchar(255) DEFAULT NULL,
  `tags` varchar(255) DEFAULT NULL,
  `slug` varchar(220) NOT NULL,
  PRIMARY KEY (`id_blog`),
  UNIQUE KEY `slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blog_album` (
  `blog_id` int NOT NULL,
  `album_id` int NOT NULL,
  PRIMARY KEY (`blog_id`,`album_id`),
  KEY `fk_blog_album_album` (`album_id`),
  CONSTRAINT `fk_blog_album_album` FOREIGN KEY (`album_id`) REFERENCES `album` (`id_album`) ON DELETE RESTRICT,
  CONSTRAINT `fk_blog_album_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blog_artista` (
  `blog_id` int NOT NULL,
  `artista_id` int NOT NULL,
  PRIMARY KEY (`blog_id`,`artista_id`),
  KEY `fk_blog_artista_artista` (`artista_id`),
  CONSTRAINT `fk_blog_artista_artista` FOREIGN KEY (`artista_id`) REFERENCES `artista` (`id_artista`) ON DELETE RESTRICT,
  CONSTRAINT `fk_blog_artista_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blog_detalle` (
  `blog_id` int NOT NULL,
  `contenido` longtext NOT NULL,
  `autor_id` int NOT NULL,
  `estado` enum('borrador','revision','publicado','archivado') NOT NULL DEFAULT 'borrador',
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `fecha_publicacion` datetime DEFAULT NULL,
  PRIMARY KEY (`blog_id`),
  KEY `idx_blog_detalle_autor` (`autor_id`),
  KEY `idx_blog_detalle_estado_fecha` (`estado`,`fecha_publicacion`),
  CONSTRAINT `fk_blog_detalle_autor` FOREIGN KEY (`autor_id`) REFERENCES `usuario` (`id_usr`) ON DELETE RESTRICT,
  CONSTRAINT `fk_blog_detalle_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `carrito_item` (
  `id_item` int NOT NULL AUTO_INCREMENT,
  `usr_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `cantidad` int NOT NULL DEFAULT '1',
  `fecha_agregado` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_item`),
  UNIQUE KEY `uq_carrito_usuario_producto` (`usr_id`,`producto_id`),
  KEY `idx_carrito_producto` (`producto_id`),
  CONSTRAINT `fk_carrito_producto` FOREIGN KEY (`producto_id`) REFERENCES `producto` (`id_producto`) ON DELETE RESTRICT,
  CONSTRAINT `fk_carrito_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE,
  CONSTRAINT `chk_carrito_cantidad` CHECK ((`cantidad` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categoria_producto` (
  `id_categoria` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id_categoria`),
  UNIQUE KEY `nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comentarios` (
  `id_com` int NOT NULL AUTO_INCREMENT,
  `comentario` varchar(500) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `estatus` enum('visible','oculto','eliminado') NOT NULL DEFAULT 'visible',
  `usr_id` int NOT NULL,
  `blog_id` int NOT NULL,
  PRIMARY KEY (`id_com`),
  KEY `idx_comentarios_blog_estado_fecha` (`blog_id`,`estatus`,`fecha`),
  KEY `idx_comentarios_usuario` (`usr_id`),
  CONSTRAINT `fk_comentarios_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE RESTRICT,
  CONSTRAINT `fk_comentarios_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE RESTRICT,
  CONSTRAINT `chk_comentarios_no_vacio` CHECK ((char_length(trim(`comentario`)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `direccion_usuario` (
  `id_direccion` int NOT NULL AUTO_INCREMENT,
  `usr_id` int NOT NULL,
  `etiqueta` varchar(60) NOT NULL DEFAULT 'Casa',
  `direccion` varchar(255) NOT NULL,
  `es_principal` tinyint(1) NOT NULL DEFAULT '0',
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_direccion`),
  KEY `idx_direccion_usuario` (`usr_id`,`es_principal`),
  CONSTRAINT `fk_direccion_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `editorial_cover_upload` (
  `token` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `usr_id` int NOT NULL,
  `filename` varchar(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `blog_id` int DEFAULT NULL,
  `request_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `result_revision` char(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  PRIMARY KEY (`token`),
  KEY `idx_cover_owner` (`usr_id`),
  KEY `idx_cover_expiry` (`expires_at`),
  KEY `fk_cover_post` (`blog_id`),
  CONSTRAINT `fk_cover_post` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE SET NULL,
  CONSTRAINT `fk_cover_user` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `guardado_publicacion` (
  `id_guardado_publicacion` int NOT NULL AUTO_INCREMENT,
  `usr_id` int NOT NULL,
  `blog_id` int NOT NULL,
  `fecha_guardado` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_guardado_publicacion`),
  UNIQUE KEY `uq_guardado_publicacion_usuario_blog` (`usr_id`,`blog_id`),
  KEY `idx_guardado_publicacion_blog` (`blog_id`),
  CONSTRAINT `fk_guardado_publicacion_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE,
  CONSTRAINT `fk_guardado_publicacion_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mobile_checkout_request` (
  `usr_id` int NOT NULL,
  `request_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `pedido_id` int NOT NULL,
  PRIMARY KEY (`usr_id`,`request_id`),
  UNIQUE KEY `uq_mobile_checkout_order` (`pedido_id`),
  CONSTRAINT `fk_mobile_checkout_order` FOREIGN KEY (`pedido_id`) REFERENCES `pedido` (`id_pedido`),
  CONSTRAINT `fk_mobile_checkout_user` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mobile_payment_session` (
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `usr_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `expires_at` datetime NOT NULL,
  `consumed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`token_hash`),
  KEY `idx_mobile_payment_expiry` (`expires_at`),
  KEY `fk_mobile_payment_user` (`usr_id`),
  KEY `fk_mobile_payment_order` (`pedido_id`),
  CONSTRAINT `fk_mobile_payment_order` FOREIGN KEY (`pedido_id`) REFERENCES `pedido` (`id_pedido`),
  CONSTRAINT `fk_mobile_payment_user` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedido` (
  `id_pedido` int NOT NULL AUTO_INCREMENT,
  `usr_id` int NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `estado` enum('pendiente','pagado','preparando','enviado','entregado','cancelado') NOT NULL DEFAULT 'pendiente',
  `total` decimal(12,2) NOT NULL DEFAULT '0.00',
  `direccion_envio` varchar(255) DEFAULT NULL,
  `paypal_order_id` varchar(64) DEFAULT NULL,
  `paypal_capture_id` varchar(64) DEFAULT NULL,
  `fecha_pago` datetime DEFAULT NULL,
  `fecha_actualizacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `subtotal` decimal(12,2) NOT NULL DEFAULT '0.00',
  `envio` decimal(12,2) NOT NULL DEFAULT '0.00',
  `descuento` decimal(12,2) NOT NULL DEFAULT '0.00',
  `impuestos` decimal(12,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id_pedido`),
  UNIQUE KEY `paypal_order_id` (`paypal_order_id`),
  UNIQUE KEY `paypal_capture_id` (`paypal_capture_id`),
  KEY `idx_pedido_usuario_fecha` (`usr_id`,`fecha`),
  CONSTRAINT `fk_pedido_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE RESTRICT,
  CONSTRAINT `chk_pedido_total` CHECK ((`total` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedido_detalle` (
  `id_detalle` int NOT NULL AUTO_INCREMENT,
  `pedido_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `nombre_producto` varchar(150) NOT NULL,
  `cantidad` int NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id_detalle`),
  UNIQUE KEY `uq_pedido_producto` (`pedido_id`,`producto_id`),
  KEY `idx_detalle_producto` (`producto_id`),
  CONSTRAINT `fk_detalle_pedido` FOREIGN KEY (`pedido_id`) REFERENCES `pedido` (`id_pedido`) ON DELETE RESTRICT,
  CONSTRAINT `fk_detalle_producto` FOREIGN KEY (`producto_id`) REFERENCES `producto` (`id_producto`) ON DELETE RESTRICT,
  CONSTRAINT `chk_detalle_cantidad` CHECK ((`cantidad` > 0)),
  CONSTRAINT `chk_detalle_precio` CHECK ((`precio_unitario` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `perfil_usuario` (
  `usr_id` int NOT NULL,
  `alias` varchar(50) DEFAULT NULL,
  `biografia` varchar(300) DEFAULT NULL,
  `avatar_url` varchar(255) DEFAULT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`usr_id`),
  CONSTRAINT `fk_perfil_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_reactions` (
  `blog_id` int NOT NULL,
  `usr_id` int NOT NULL,
  `reaction_id` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`blog_id`,`usr_id`),
  KEY `idx_post_reactions_counts` (`blog_id`,`reaction_id`),
  KEY `idx_post_reactions_user` (`usr_id`),
  KEY `fk_post_reactions_type` (`reaction_id`),
  CONSTRAINT `fk_post_reactions_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE,
  CONSTRAINT `fk_post_reactions_type` FOREIGN KEY (`reaction_id`) REFERENCES `tipo_reaccion` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_post_reactions_user` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `producto` (
  `id_producto` int NOT NULL AUTO_INCREMENT,
  `categoria_id` int NOT NULL,
  `album_id` int DEFAULT NULL,
  `nombre` varchar(150) NOT NULL,
  `slug` varchar(180) DEFAULT NULL,
  `marca` varchar(100) DEFAULT NULL,
  `descripcion` text,
  `precio` decimal(10,2) NOT NULL,
  `stock` int NOT NULL DEFAULT '0',
  `imagen` varchar(255) DEFAULT NULL,
  `imagen_2` varchar(255) DEFAULT NULL,
  `imagen_3` varchar(255) DEFAULT NULL,
  `imagen_4` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_producto`),
  UNIQUE KEY `uq_producto_slug` (`slug`),
  KEY `idx_producto_categoria` (`categoria_id`),
  KEY `idx_producto_nombre` (`nombre`),
  KEY `idx_producto_album` (`album_id`),
  CONSTRAINT `fk_producto_album` FOREIGN KEY (`album_id`) REFERENCES `album` (`id_album`) ON DELETE SET NULL,
  CONSTRAINT `fk_producto_categoria` FOREIGN KEY (`categoria_id`) REFERENCES `categoria_producto` (`id_categoria`) ON DELETE RESTRICT,
  CONSTRAINT `chk_producto_precio` CHECK ((`precio` >= 0)),
  CONSTRAINT `chk_producto_stock` CHECK ((`stock` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rol` (
  `id_rol` tinyint unsigned NOT NULL,
  `nombre` varchar(60) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id_rol`),
  UNIQUE KEY `nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `solicitud_factura` (
  `pedido_id` int NOT NULL,
  `rfc` varchar(13) NOT NULL,
  `nombre_fiscal` varchar(254) NOT NULL,
  `codigo_postal` char(5) NOT NULL,
  `regimen_fiscal` char(3) DEFAULT NULL,
  `uso_cfdi` char(4) DEFAULT NULL,
  `solicitada_en` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`pedido_id`),
  CONSTRAINT `fk_solicitud_factura_pedido` FOREIGN KEY (`pedido_id`) REFERENCES `pedido` (`id_pedido`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tipo_reaccion` (
  `id` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `icono` varchar(32) NOT NULL,
  `color` char(7) NOT NULL,
  `orden` tinyint NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuario` (
  `id_usr` int NOT NULL AUTO_INCREMENT,
  `nom_usr` varchar(100) NOT NULL,
  `mail` varchar(150) NOT NULL,
  `pass` varchar(255) NOT NULL,
  `dir_usr` varchar(255) DEFAULT NULL,
  `tip_usu` tinyint unsigned NOT NULL DEFAULT '1',
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `auth_version` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id_usr`),
  UNIQUE KEY `mail` (`mail`),
  KEY `fk_usuario_rol` (`tip_usu`),
  CONSTRAINT `fk_usuario_rol` FOREIGN KEY (`tip_usu`) REFERENCES `rol` (`id_rol`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wishlist_item` (
  `id_item` int NOT NULL AUTO_INCREMENT,
  `usr_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `fecha_guardado` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_item`),
  UNIQUE KEY `uq_wishlist_usuario_producto` (`usr_id`,`producto_id`),
  KEY `idx_wishlist_producto` (`producto_id`),
  CONSTRAINT `fk_wishlist_producto` FOREIGN KEY (`producto_id`) REFERENCES `producto` (`id_producto`) ON DELETE RESTRICT,
  CONSTRAINT `fk_wishlist_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
