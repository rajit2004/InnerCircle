-- Round 12, Feature: message reactions. One reaction per message (a single
-- emoji, or null for none) -- kept simple rather than a reactions table with
-- multiple-per-message support, since this is a 1:1 conversation (you and
-- one persona), not a group chat where several people might react
-- differently to the same message.
--
-- Safe to run multiple times.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reaction TEXT;