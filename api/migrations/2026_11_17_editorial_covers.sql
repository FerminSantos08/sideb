CREATE TABLE IF NOT EXISTS editorial_cover_upload (
 token CHAR(32) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
 usr_id INT NOT NULL,
 filename VARCHAR(64) NOT NULL,
 expires_at DATETIME NOT NULL,
 blog_id INT NULL,
 result_revision CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
 request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
 KEY idx_cover_owner(usr_id), KEY idx_cover_expiry(expires_at),
 CONSTRAINT fk_cover_user FOREIGN KEY(usr_id) REFERENCES usuario(id_usr),
 CONSTRAINT fk_cover_post FOREIGN KEY(blog_id) REFERENCES blog(id_blog) ON DELETE SET NULL
) ENGINE=InnoDB;
