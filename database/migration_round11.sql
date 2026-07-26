-- Migration for Round 11: forgot-password flow + custom persona creation.
-- Safe to run multiple times.

-- Forgot password: a token + expiry stored directly on the user row rather
-- than a separate table -- only ever one pending reset matters at a time,
-- issuing a new one naturally invalidates the old (see AuthService.forgotPassword).
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_token TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMPTZ;

-- Custom personas: null = built-in/global persona (the original 4 seeded
-- ones), non-null = a persona a specific user created for themselves.
-- ON DELETE CASCADE means if a user account is ever deleted, their custom
-- personas (and, transitively, those personas' conversations/memories/
-- scheduled check-ins, which already cascade from personas) go with it.
ALTER TABLE personas ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE;

-- Verify
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'profiles' AND column_name IN ('reset_token', 'reset_token_expires_at');
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'personas' AND column_name = 'owner_user_id';