-- Suporte a credencial local (Argon2). Nulo para identidades AD (validadas via LDAP bind).
-- Em produção todos logam via LDAP; usado em dev (LDAP indisponível) e como reserva.
ALTER TABLE app_user ADD COLUMN password_hash text;
