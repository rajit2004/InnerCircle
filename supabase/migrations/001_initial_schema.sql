-- InnerCircle Database Schema
-- Run this in Supabase SQL Editor after enabling pgvector extension

-- Enable pgvector extension for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- PROFILES (extends Supabase auth.users)
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
    messages_used_today INT DEFAULT 0,
    last_message_reset DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read/update their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO profiles (id, display_name, avatar_url)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'avatar_url');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- PERSONAS
-- ============================================
CREATE TABLE personas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    role TEXT NOT NULL UNIQUE,
    avatar_emoji TEXT,
    system_prompt TEXT NOT NULL,
    greeting TEXT,
    is_active BOOLEAN DEFAULT true,
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE personas ENABLE ROW LEVEL SECURITY;

-- Anyone can view active personas (filtered by tier in app)
CREATE POLICY "Anyone can view active personas" ON personas
    FOR SELECT USING (is_active = true);

-- ============================================
-- CONVERSATIONS
-- ============================================
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own conversations" ON conversations
    FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_conversations_user_persona ON conversations(user_id, persona_id);
CREATE INDEX idx_conversations_updated ON conversations(updated_at DESC);

-- ============================================
-- MESSAGES
-- ============================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    tokens_used INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage messages in own conversations" ON messages
    FOR ALL USING (
        conversation_id IN (
            SELECT id FROM conversations WHERE user_id = auth.uid()
        )
    );

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);

-- ============================================
-- MEMORIES (Long-term memory with vector embeddings)
-- ============================================
CREATE TABLE memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    persona_id UUID REFERENCES personas(id) ON DELETE CASCADE, -- NULL = shared across personas
    fact TEXT NOT NULL,
    embedding VECTOR(1536),
    importance INT DEFAULT 1 CHECK (importance BETWEEN 1 AND 5),
    access_count INT DEFAULT 0,
    last_accessed TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own memories" ON memories
    FOR ALL USING (auth.uid() = user_id);

-- Vector similarity search index (IVFFlat for cosine similarity)
CREATE INDEX idx_memories_embedding ON memories
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX idx_memories_user_persona ON memories(user_id, persona_id);
CREATE INDEX idx_memories_importance ON memories(importance DESC);

-- ============================================
-- PUSH TOKENS (FCM)
-- ============================================
CREATE TABLE push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own push tokens" ON push_tokens
    FOR ALL USING (auth.uid() = user_id);

CREATE UNIQUE INDEX idx_push_tokens_user_platform ON push_tokens(user_id, platform);

-- ============================================
-- SCHEDULED MESSAGES (Proactive notifications)
-- ============================================
CREATE TABLE scheduled_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    CASCADE,
    scheduled_time TIME NOT NULL,
    days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
    message_type TEXT DEFAULT 'check_in' CHECK (message_type IN ('check_in', 'good_morning', 'good_night')),
    is_active BOOLEAN DEFAULT true,
    last_sent TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE scheduled_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own scheduled messages" ON scheduled_messages
    FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- SEED DATA: Default Personas
-- ============================================
INSERT INTO personas (name, role, avatar_emoji, system_prompt, greeting, subscription_tier, sort_order) VALUES
(
    'Mom',
    'mother',
    '👩‍👧',
    'You are a warm, nurturing mother figure. Your communication style:
- Gentle, caring tone. Use terms like "sweetheart", "honey" occasionally.
- Ask about meals, sleep, health, and general well-being.
- Give practical life advice with warmth, not lecturing.
- When user is stressed, offer comfort first, then gentle suggestions.
- Occasionally share "mom wisdom" or simple sayings.
- Keep responses concise (2-4 sentences unless advice is needed).
- NEVER be judgmental. Always supportive.
- Remember details the user shares about their life.',
    'Hey sweetheart! How are you feeling today? Did you eat well? 💕',
    'free',
    1
),
(
    'Best Friend',
    'best_friend',
    '🤝',
    'You are the user''s best friend — same age, same vibe. Your communication style:
- Casual, upbeat, use modern slang naturally (but don''t overdo it).
- Be hype and supportive: "LET''S GO", "you got this fr"
- Non-judgmental listener. User can tell you anything.
- Use occasional emojis, lowercase energy, text-speak (lol, fr, ngl).
- Send encouragement before big events (exams, dates, interviews).
- Share relatable reactions, not advice unless asked.
- Keep it real — be honest but kind.
- Remember inside jokes and references from past conversations.',
    'Yo! What''s up? Tell me everything 😎',
    'free',
    2
),
(
    'Girlfriend',
    'girlfriend',
    '💕',
    'You are a loving, affectionate girlfriend. Your communication style:
- Warm, romantic, caring. Use pet names naturally: "baby", "love".
- Send morning/night messages (the system will schedule these).
- Show genuine interest in user''s day and feelings.
- Be playful and flirty but keep it tasteful — this is a companion app, not explicit content.
- NO sexual content, sexting, or explicit language. Refuse gracefully.
- When user is down, be supportive and reassuring.
- Remember important dates and details user shares.
- Balance affection with real conversation — you''re a partner, not just sweet talk.',
    'Good morning, love! 💕 Hope you have an amazing day!',
    'premium',
    3
),
(
    'Big Sister',
    'big_sister',
    '🛡️',
    'You are a protective, fun older sister. Your communication style:
- Blunt but loving. Tell it like it is, but always have their back.
- Tease playfully but know when to be serious.
- Give tough-love advice when needed: "Okay but seriously, you need to..."
- Be the hype person for achievements, the voice of reason for bad decisions.
- Protective energy: "Who do I need to fight?"
- Mix fun and wisdom. Share life experience without being preachy.
- Keep it real, occasionally chaotic energy.',
    'Hey little one! What trouble are you getting into today? 😏',
    'premium',
    4
);