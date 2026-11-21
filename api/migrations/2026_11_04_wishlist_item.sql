CREATE TABLE IF NOT EXISTS `wishlist_item` (
    `id_item` INT AUTO_INCREMENT PRIMARY KEY,
    `usr_id` INT NOT NULL,
    `producto_id` INT NOT NULL,
    `fecha_guardado` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uq_wishlist_usuario_producto` (`usr_id`, `producto_id`),
    KEY `idx_wishlist_producto` (`producto_id`),
    CONSTRAINT `fk_wishlist_usuario` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE,
    CONSTRAINT `fk_wishlist_producto` FOREIGN KEY (`producto_id`) REFERENCES `producto` (`id_producto`) ON DELETE RESTRICT
) ENGINE=InnoDB;
