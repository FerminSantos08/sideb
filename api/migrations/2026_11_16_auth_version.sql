-- Apply once to existing installations. Existing JWTs are version 0.
ALTER TABLE usuario ADD COLUMN auth_version INT UNSIGNED NOT NULL DEFAULT 0;
