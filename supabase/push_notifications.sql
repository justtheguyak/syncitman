-- ====================================================================
-- CoupleSync Push Notifications Setup (FCM & Device Tokens)
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/pisabzyatipobpwczbzq/sql
-- ====================================================================

-- 1. Create table to store device push notification tokens
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  platform TEXT DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_id ON public.user_push_tokens(user_id);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
DROP POLICY IF EXISTS "tokens_select_own" ON public.user_push_tokens;
CREATE POLICY "tokens_select_own" ON public.user_push_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- Allow reading partner's tokens to dispatch notifications
DROP POLICY IF EXISTS "tokens_select_partner" ON public.user_push_tokens;
CREATE POLICY "tokens_select_partner" ON public.user_push_tokens
  FOR SELECT USING (
    user_id IN (
      SELECT partner_id FROM public.profiles WHERE id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tokens_insert_own" ON public.user_push_tokens;
CREATE POLICY "tokens_insert_own" ON public.user_push_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tokens_update_own" ON public.user_push_tokens;
CREATE POLICY "tokens_update_own" ON public.user_push_tokens
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "tokens_delete_own" ON public.user_push_tokens;
CREATE POLICY "tokens_delete_own" ON public.user_push_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- 4. Enable Realtime replication for tokens
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_push_tokens'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_push_tokens;
  END IF;
END $$;
