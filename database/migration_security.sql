-- SECURITY: add account lockout fields to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP;
