-- Apply before enabling REACTIONS_ENABLED. Publication reactions only.
CREATE TABLE IF NOT EXISTS `tipo_reaccion` (
    `id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    `nombre` VARCHAR(50) NOT NULL,
    `icono` VARCHAR(32) NOT NULL,
    `color` CHAR(7) NOT NULL,
    `orden` TINYINT NOT NULL
) ENGINE=InnoDB;

INSERT INTO tipo_reaccion (id,nombre,icono,color,orden) VALUES
('me_encanta','Me encanta','heart','#C16A60',1),
('temazo','Temazo','music-2','#858C77',2),
('lo_escucharia','Lo escuché','headphones','#B89B72',3),
('sorprendente','Sorprendente','sparkles','#A18BB6',4)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre),icono=VALUES(icono),color=VALUES(color),orden=VALUES(orden);

CREATE TABLE IF NOT EXISTS `post_reactions` (
    `blog_id` INT NOT NULL,
    `usr_id` INT NOT NULL,
    `reaction_id` VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`blog_id`, `usr_id`),
    KEY `idx_post_reactions_counts` (`blog_id`, `reaction_id`),
    KEY `idx_post_reactions_user` (`usr_id`),
    CONSTRAINT `fk_post_reactions_type` FOREIGN KEY (`reaction_id`) REFERENCES `tipo_reaccion` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_post_reactions_blog` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`) ON DELETE CASCADE,
    CONSTRAINT `fk_post_reactions_user` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE CASCADE
) ENGINE=InnoDB;
