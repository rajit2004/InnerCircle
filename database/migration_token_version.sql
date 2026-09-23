-- SECURITY: JWT revocation on password change/reset.
-- token_version is embedded in new JWTs as the "tv" claim; JwtAuthFilter
-- rejects any token whose claim does not match this column, so changing
-- a password kills every previously issued token for that user.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS token_version INTEGER DEFAULT 0;
