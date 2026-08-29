-- Migration: Restructure data model
-- Adds UserPreferences, renames personas→companions concept,
-- adds new fields to existing tables.

-- ── User new columns ──────────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'en';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'UTC';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ── UserPreferences ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    preferred_name TEXT,
    communication_style TEXT DEFAULT 'casual',
    response_length TEXT DEFAULT 'moderate' CHECK (response_length IN ('short', 'moderate', 'detailed')),
    interests TEXT DEFAULT '[]',
    goals TEXT DEFAULT '[]',
    memory_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Persona → Companion columns ───────────────────────────────────────────
ALTER TABLE personas ADD COLUMN IF NOT EXISTS personality TEXT;
ALTER TABLE personas ADD COLUMN IF NOT EXISTS voice TEXT;
ALTER TABLE personas ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE CASCADE;

-- Backfill personality from system_prompt for existing personas
UPDATE personas SET personality = system_prompt WHERE personality IS NULL;

-- ── Memory new columns ────────────────────────────────────────────────────
ALTER TABLE memories ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE memories ADD COLUMN IF NOT EXISTS memory_type TEXT DEFAULT 'semantic';
ALTER TABLE memories ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE memories ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill content from fact for existing memories
UPDATE memories SET content = fact WHERE content IS NULL;

-- ── Indexes for new columns ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences (user_id);
CREATE INDEX IF NOT EXISTS idx_memories_deleted_at ON memories (deleted_at) WHERE deleted_at IS NULL;
