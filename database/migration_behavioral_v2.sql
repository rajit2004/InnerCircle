-- Migration: Behavioral Architecture v2
-- Adds message metadata, relationships table, memory types, conversation state

-- ── Message metadata (JSONB) ──────────────────────────────────────────────
ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata TEXT DEFAULT '{}';

-- ── Memory type constraints ───────────────────────────────────────────────
-- Update existing memories to have proper types
UPDATE memories SET memory_type = 'semantic' WHERE memory_type = 'fact';

-- ── Relationships ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS relationships (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    affinity_score REAL DEFAULT 0.0,
    interaction_count INT DEFAULT 0,
    last_interaction_at TIMESTAMPTZ,
    relationship_stage TEXT DEFAULT 'new' CHECK (relationship_stage IN ('new', 'building', 'established', 'deep')),
    inside_jokes TEXT DEFAULT '[]',
    shared_topics TEXT DEFAULT '[]',
    preferred_response_style TEXT,
    user_nickname TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, persona_id)
);

CREATE INDEX IF NOT EXISTS idx_relationships_user_persona ON relationships (user_id, persona_id);

-- ── Indexes ───────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_memories_type ON memories (memory_type);
