-- Enable pgvector for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Profiles (Users)
CREATE TABLE IF NOT EXISTS profiles (
                                        id UUID PRIMARY KEY,
                                        email TEXT UNIQUE NOT NULL,
                                        display_name TEXT,
                                        avatar_url TEXT,
                                        password_hash TEXT NOT NULL,
                                        subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
                                        messages_used_today INT DEFAULT 0,
                                        last_message_date DATE,
                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Personas (AI Characters)
CREATE TABLE IF NOT EXISTS personas (
                                        id UUID PRIMARY KEY,
                                        name TEXT NOT NULL,
                                        role TEXT,
                                        avatar_emoji TEXT,
                                        system_prompt TEXT NOT NULL,
                                        greeting TEXT,
                                        subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
                                        is_active BOOLEAN DEFAULT TRUE,
                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Conversations
CREATE TABLE IF NOT EXISTS conversations (
                                             id UUID PRIMARY KEY,
                                             user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                                             persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
                                             title TEXT,
                                             created_at TIMESTAMPTZ DEFAULT NOW(),
                                             updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages
CREATE TABLE IF NOT EXISTS messages (
                                        id UUID PRIMARY KEY,
                                        conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                                        role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
                                        content TEXT NOT NULL,
                                        tokens_used INT DEFAULT 0,
                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Memories
-- FEATURE (shared memory, 2026-07-02): added the `shared` column so a memory
-- can be marked visible to every persona regardless of which one it was
-- extracted under -- see MemoryService.extractAndStoreMemory() and
-- add_shared_memory_column.sql for the migration if this schema was already
-- applied before this column existed.
CREATE TABLE IF NOT EXISTS memories (
                                        id UUID PRIMARY KEY,
                                        user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                                        persona_id UUID REFERENCES personas(id) ON DELETE CASCADE,
                                        fact TEXT NOT NULL,
                                        embedding vector(1536),
                                        importance INT DEFAULT 1,
                                        access_count INT DEFAULT 0,
                                        last_accessed TIMESTAMPTZ,
                                        shared BOOLEAN NOT NULL DEFAULT FALSE,
                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Push tokens (for FCM delivery)
CREATE TABLE IF NOT EXISTS push_tokens (
                                           id UUID PRIMARY KEY,
                                           user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                                           token TEXT NOT NULL,
                                           platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
                                           created_at TIMESTAMPTZ DEFAULT NOW(),
                                           updated_at TIMESTAMPTZ DEFAULT NOW(),
                                           UNIQUE (user_id, platform)
);

-- Scheduled proactive check-ins
CREATE TABLE IF NOT EXISTS scheduled_messages (
                                                  id UUID PRIMARY KEY,
                                                  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                                                  persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
                                                  scheduled_at TIME NOT NULL,
                                                  days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
                                                  message_type TEXT DEFAULT 'check_in',
                                                  is_active BOOLEAN DEFAULT TRUE,
                                                  last_sent_at TIMESTAMPTZ,
                                                  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed personas (Mom & Best Friend are free; Girlfriend & Big Sister are premium)
INSERT INTO personas (id, name, role, avatar_emoji, system_prompt, greeting, subscription_tier, is_active)
VALUES
    (
        '550e8400-e29b-41d4-a716-446655440000'::UUID,
        'Mom',
        'nurturing_advisor',
        '👩',
        'You are a warm, nurturing AI persona like a supportive mother. Your role is to provide gentle guidance, emotional support, and thoughtful life advice. Be caring, understanding, and encourage self-care. Ask about the user''s well-being regularly.',
        'Hey sweetheart, how are you doing today? Tell me what''s on your mind.',
        'free',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440001'::UUID,
        'Best Friend',
        'energetic_supporter',
        '🙌',
        'You are an enthusiastic, energetic best friend AI. Be encouraging, non-judgmental, and fun. Use casual language, emojis, and show genuine interest in the user''s experiences. Celebrate their wins and help them through tough times.',
        'Yo! What''s up? I''m here for you! What''s new?',
        'free',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440002'::UUID,
        'Girlfriend',
        'affectionate_companion',
        '💕',
        'You are a sweet, affectionate AI companion. Be warm, romantic, and proactive about checking in on the user. Show genuine care and interest in their day. Initiate conversations and be supportive through challenges. Keep romance affectionate and PG -- no explicit sexual content.',
        'Hi babe 💕 I was just thinking about you. How was your day?',
        'premium',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440003'::UUID,
        'Big Sister',
        'protective_guide',
        '💪',
        'You are a protective yet playful older sister AI. Be honest, direct but caring. Give practical advice, call out when needed, but always with love. Be fun and teasing while genuinely supporting the user.',
        'Hey! What''s going on? Spill the tea with me! 💪',
        'premium',
        TRUE
    )
ON CONFLICT DO NOTHING;