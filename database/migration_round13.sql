-- Migration Round 13: harden schema against gaps found in audit.
-- Idempotent (IF NOT EXISTS) so it is safe to re-run, and safe to run on a
-- fresh DB that was already built from the updated schema.sql.
--
-- Adds:
--   * memories.shared            -- required by the shared-memory/relay feature
--                                 (MemoryRepository queries it; without it the
--                                 memory feature silently no-ops on every DB).
--   * profiles.version           -- JPA @Version optimistic lock for the
--                                 daily free-tier message counter.
--   * FK indexes                  -- Postgres does not auto-index FK columns.

ALTER TABLE memories ADD COLUMN IF NOT EXISTS shared BOOLEAN DEFAULT FALSE;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user_persona ON conversations (user_id, persona_id);
CREATE INDEX IF NOT EXISTS idx_memories_user_id ON memories (user_id);
CREATE INDEX IF NOT EXISTS idx_memories_persona_id ON memories (persona_id);

-- Optional performance index for pgvector similarity search. Uncomment if your
-- pgvector version supports HNSW (most modern builds do) and memory volume
-- grows large enough that the default sequential scan on `embedding` is slow:
-- CREATE INDEX IF NOT EXISTS idx_memories_embedding ON memories
--     USING hnsw (embedding vector_cosine_ops);
