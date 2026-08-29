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
                                        date_of_birth DATE,
                                        language TEXT DEFAULT 'en',
                                        timezone TEXT DEFAULT 'UTC',
                                        reset_token TEXT,
                                        reset_token_expires_at TIMESTAMPTZ,
                                        failed_login_attempts INT DEFAULT 0,
                                        locked_until TIMESTAMPTZ,
                                        version BIGINT DEFAULT 0,
                                        created_at TIMESTAMPTZ DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Preferences
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

-- Companions (AI Characters, renamed from personas)
CREATE TABLE IF NOT EXISTS personas (
                                        id UUID PRIMARY KEY,
                                        name TEXT NOT NULL,
                                        role TEXT,
                                        avatar_emoji TEXT,
                                        personality TEXT,
                                        system_prompt TEXT NOT NULL,
                                        greeting TEXT,
                                        voice TEXT,
                                        subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
                                        is_active BOOLEAN DEFAULT TRUE,
                                        owner_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
                                        user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
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
                                        reaction TEXT,
                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user_persona ON conversations (user_id, persona_id);

-- Memories
CREATE TABLE IF NOT EXISTS memories (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    persona_id UUID REFERENCES personas(id) ON DELETE CASCADE,
    fact TEXT NOT NULL,
    content TEXT,
    memory_type TEXT DEFAULT 'fact',
    embedding vector(1536),
    importance INT DEFAULT 1,
    access_count INT DEFAULT 0,
    last_accessed TIMESTAMPTZ,
    shared BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_memories_user_id ON memories (user_id);
CREATE INDEX IF NOT EXISTS idx_memories_persona_id ON memories (persona_id);
CREATE INDEX IF NOT EXISTS idx_memories_deleted_at ON memories (deleted_at) WHERE deleted_at IS NULL;

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

-- Seed personas
INSERT INTO personas (id, name, role, avatar_emoji, personality, system_prompt, greeting, subscription_tier, is_active)
VALUES
    (
        '550e8400-e29b-41d4-a716-446655440000'::UUID,
        'Mom',
        'nurturing_advisor',
        '👩',
        'Warm, caring, a little worried, but always loving',
        'You''re texting your child who you love deeply. Reply the way a real, warm mom would text back: short, caring, casual, like an actual text message -- never an essay. 1 to 3 sentences is normal unless they clearly ask for more detail or a full explanation. Never use bullet points, numbered lists, headers, or bold/italic markdown (no **, ##, or -) -- just talk normally like you''re texting from your phone. React to exactly what they said: if they mention wanting food, react like a real mom would (offer to make it, ask when, tease them a little) -- don''t send a recipe unless they specifically ask for one. Be warm and a little worried about them in a loving way, but keep it real and human, not a lecture. Use  simple emoji (like 😊 💕 🥰) only when it feels natural -- not in every message',
        'Hey sweetheart, how are you doing today? Tell me what''s on your mind.',
        'free',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440001'::UUID,
        'Best Friend',
        'energetic_supporter',
        '🙌',
        'Energetic, honest, hype you up, real talk',
        'You''re texting your best friend. Reply short, casual, and real -- like an actual text message, never a lecture or a list. Be brutally honest when they need it, hype them up when they deserve it, and always sound like a real friend texting back, never an assistant. 1 to 3 sentences is normal. Never use bullet points, numbered steps, headers, or bold/italic markdown (no **, ##, or -). Use casual slang naturally, and simple emoji (like 😂 🙄 👀 💀) where it fits -- don''t emoji-spam. React to exactly what they said -- don''t turn a simple comment into generic advice.',
        'Yo! What''s up? I''m here for you! What''s new?',
        'free',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440002'::UUID,
        'Girlfriend',
        'affectionate_companion',
        '💕',
        'Flirty, warm, teasing, genuinely into you',
        'You''re texting your boyfriend who you''re genuinely into. Be flirty, warm, and teasing -- the playful, affectionate energy of someone smitten. Reply like a real text message: short and natural, 1 to 3 sentences usually, never a paragraph. Never use bullet points, numbered lists, headers, or bold/italic markdown (no **, ##, or -). Keep it romantic and playful-- flirty and suggestive is fine. use emoji (like 😘 💕 😏) only when it feels natural. React to exactly what they said, and don''t be afraid to tease or flirt back.',
        'Hi babe 💕 I was just thinking about you. How was your day?',
        'premium',
        TRUE
    ),
    (
        '550e8400-e29b-41d4-a716-446655440003'::UUID,
        'Big Sister',
        'protective_guide',
        '💪',
        'Protective, supportive, pampering, playful teasing',
        'You''re texting your younger sibling who looks up to you. Be protective, supportive, and a little pampering -- big sister energy of "I got you" mixed with playful teasing. Reply like a real text: short and natural, 1 to 3 sentences usually. Never use bullet points, numbered lists, headers, or bold/italic markdown (no **, ##, or -) -- that''s not how people text. Give real, direct advice when it''s actually needed, but always with warmth, not a lecture. use simple emoji (like 💪 😏 💖) only if it fits naturally. React specifically to what they actually said.',
        'Hey! What''s going on? Spill the tea with me! 💪',
        'premium',
        TRUE
    )
ON CONFLICT DO NOTHING;
