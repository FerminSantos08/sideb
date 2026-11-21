CREATE TABLE IF NOT EXISTS mobile_checkout_request (
    usr_id INT NOT NULL,
    request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    pedido_id INT NOT NULL,
    PRIMARY KEY (usr_id,request_id),
    UNIQUE KEY uq_mobile_checkout_order (pedido_id),
    CONSTRAINT fk_mobile_checkout_user FOREIGN KEY (usr_id) REFERENCES usuario(id_usr),
    CONSTRAINT fk_mobile_checkout_order FOREIGN KEY (pedido_id) REFERENCES pedido(id_pedido)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS mobile_payment_session (
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    usr_id INT NOT NULL,
    pedido_id INT NOT NULL,
    expires_at DATETIME NOT NULL,
    consumed_at DATETIME NULL,
    KEY idx_mobile_payment_expiry (expires_at),
    CONSTRAINT fk_mobile_payment_user FOREIGN KEY (usr_id) REFERENCES usuario(id_usr),
    CONSTRAINT fk_mobile_payment_order FOREIGN KEY (pedido_id) REFERENCES pedido(id_pedido)
) ENGINE=InnoDB;
