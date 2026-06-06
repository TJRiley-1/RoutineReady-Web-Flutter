-- RoutineReady Mobile - Database Migrations
-- Run in Supabase SQL Editor

-- 1. Add missing columns to display_settings
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS top_banner_height int DEFAULT 48;
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS bottom_banner_height int DEFAULT 48;
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS selected_sprite text DEFAULT 'penguin';
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS selected_surface text DEFAULT 'ice';
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS road_height int DEFAULT 32;

-- 2. Display Sessions - tracks active device connections
CREATE TABLE IF NOT EXISTS display_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES schools ON DELETE CASCADE,
  device_id text NOT NULL,
  device_name text DEFAULT 'Display',
  session_type text NOT NULL DEFAULT 'display',  -- 'display' or 'admin_only'
  is_active boolean DEFAULT true,
  last_heartbeat timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(school_id, device_id)
);

ALTER TABLE display_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own school sessions"
  ON display_sessions FOR ALL
  USING (school_id IN (SELECT id FROM schools WHERE owner_id = auth.uid()));

-- 3. Subscriptions - licensing/slot limits
CREATE TABLE IF NOT EXISTS subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES schools ON DELETE CASCADE,
  plan text DEFAULT 'free',
  max_display_slots int DEFAULT 1,
  max_admin_slots int DEFAULT 1,
  status text DEFAULT 'active',
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own subscription"
  ON subscriptions FOR SELECT
  USING (school_id IN (SELECT id FROM schools WHERE owner_id = auth.uid()));

-- 4. Enable Realtime on sync-critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE active_timeline;
ALTER PUBLICATION supabase_realtime ADD TABLE display_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE custom_themes;

-- 5. Add updated_at triggers for change detection
ALTER TABLE active_timeline ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE display_settings ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON active_timeline
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON display_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 6. Stale session cleanup function (call via pg_cron or Supabase Edge Function)
CREATE OR REPLACE FUNCTION cleanup_stale_sessions()
RETURNS void AS $$
BEGIN
  UPDATE display_sessions
  SET is_active = false
  WHERE is_active = true
    AND last_heartbeat < now() - interval '5 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Enable pg_cron extension and schedule cleanup every 5 minutes
-- NOTE: pg_cron must be enabled in your Supabase project (Database > Extensions)
-- After enabling, run:
-- SELECT cron.schedule('cleanup-stale-sessions', '*/5 * * * *', 'SELECT cleanup_stale_sessions()');

-- ═══════════════════════════════════════════════════════════════
-- 8. ROW LEVEL SECURITY — all tables must be protected before launch
--
-- Safe to re-run: DROP POLICY IF EXISTS before each CREATE POLICY
-- ═══════════════════════════════════════════════════════════════

-- ── schools ──
-- Users can only access their own school record
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users select own school" ON schools;
CREATE POLICY "Users select own school"
  ON schools FOR SELECT
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users insert own school" ON schools;
CREATE POLICY "Users insert own school"
  ON schools FOR INSERT
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users update own school" ON schools;
CREATE POLICY "Users update own school"
  ON schools FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users delete own school" ON schools;
CREATE POLICY "Users delete own school"
  ON schools FOR DELETE
  USING (owner_id = auth.uid());

-- ── RLS helper functions live in a non-API-exposed `private` schema ──
-- They are SECURITY DEFINER and only ever report facts about the current
-- auth.uid(). Keeping them out of `public` stops the Supabase security advisor
-- flagging them as publicly-callable RPCs, while RLS policies can still call
-- them (RLS runs as the querying role, which holds USAGE on `private` and
-- EXECUTE on each function — see the grants block at the end of this file).
-- DO NOT move these back to `public` or revoke EXECUTE: doing so breaks every
-- org-aware policy with "42501 permission denied for function ...".
CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO authenticated, anon;

-- ── Helper function: check if school belongs to current user ──
-- Used by all child tables to avoid repeating the subquery
CREATE OR REPLACE FUNCTION private.user_owns_school(p_school_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM schools WHERE id = p_school_id AND owner_id = auth.uid()
  );
$$;

-- ── templates ──
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own templates" ON templates;
CREATE POLICY "Users manage own templates"
  ON templates FOR ALL
  USING (private.user_owns_school(school_id))
  WITH CHECK (private.user_owns_school(school_id));

-- ── tasks ──
-- Tasks belong to templates; verify ownership through the template's school_id
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own tasks" ON tasks;
CREATE POLICY "Users manage own tasks"
  ON tasks FOR ALL
  USING (
    template_id IN (
      SELECT id FROM templates WHERE private.user_owns_school(school_id)
    )
  )
  WITH CHECK (
    template_id IN (
      SELECT id FROM templates WHERE private.user_owns_school(school_id)
    )
  );

-- ── active_timeline ──
ALTER TABLE active_timeline ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own timeline" ON active_timeline;
CREATE POLICY "Users manage own timeline"
  ON active_timeline FOR ALL
  USING (private.user_owns_school(school_id))
  WITH CHECK (private.user_owns_school(school_id));

-- ── display_settings ──
ALTER TABLE display_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own display settings" ON display_settings;
CREATE POLICY "Users manage own display settings"
  ON display_settings FOR ALL
  USING (private.user_owns_school(school_id))
  WITH CHECK (private.user_owns_school(school_id));

-- ── weekly_schedules ──
ALTER TABLE weekly_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own weekly schedules" ON weekly_schedules;
CREATE POLICY "Users manage own weekly schedules"
  ON weekly_schedules FOR ALL
  USING (private.user_owns_school(school_id))
  WITH CHECK (private.user_owns_school(school_id));

-- ── custom_themes ──
ALTER TABLE custom_themes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own custom themes" ON custom_themes;
CREATE POLICY "Users manage own custom themes"
  ON custom_themes FOR ALL
  USING (private.user_owns_school(school_id))
  WITH CHECK (private.user_owns_school(school_id));

-- ── contact_messages (if table exists from web app) ──
-- Anyone can submit a contact form (even unauthenticated via landing page)
-- Only service_role can read messages (admin dashboard, not in this app)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'contact_messages') THEN
    ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Anyone can insert contact messages" ON contact_messages;
    CREATE POLICY "Anyone can insert contact messages"
      ON contact_messages FOR INSERT
      WITH CHECK (true);
    -- No SELECT/UPDATE/DELETE policy = nobody can read via anon/authenticated key
    -- Use service_role key in a separate admin tool to read contact messages
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- 9. Extend subscriptions for RevenueCat + multi-source support
-- ═══════════════════════════════════════════════════════════════

-- User-level subscriptions (App Store / RevenueCat)
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users ON DELETE CASCADE;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS source text DEFAULT 'manual';
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS product_id text;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS period_type text;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- school_id is now nullable (user-level subs won't have one initially)
ALTER TABLE subscriptions ALTER COLUMN school_id DROP NOT NULL;

-- One active RevenueCat subscription per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_user_source
  ON subscriptions (user_id, source)
  WHERE user_id IS NOT NULL AND source = 'revenuecat';

-- Updated RLS: users can read their own user-level OR school-level subscriptions
DROP POLICY IF EXISTS "Users read own subscription" ON subscriptions;
CREATE POLICY "Users read own subscription"
  ON subscriptions FOR SELECT
  USING (
    user_id = auth.uid()
    OR school_id IN (SELECT id FROM schools WHERE owner_id = auth.uid())
  );

-- updated_at trigger
CREATE OR REPLACE FUNCTION update_subscriptions_updated_at()
RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER set_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_subscriptions_updated_at();

-- ═══════════════════════════════════════════════════════════════
-- 10. Multi-Account School Organization Model
-- ═══════════════════════════════════════════════════════════════

-- Organizations table
CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- Org members table (links users to organizations with roles)
CREATE TABLE IF NOT EXISTS org_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES organizations ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('teacher', 'staff', 'display', 'school_admin')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(org_id, user_id)
);
ALTER TABLE org_members ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON org_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org_id ON org_members(org_id);

-- Add org_id to schools and subscriptions
ALTER TABLE schools ADD COLUMN IF NOT EXISTS org_id uuid REFERENCES organizations ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_schools_org_id ON schools(org_id);
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS org_id uuid REFERENCES organizations ON DELETE CASCADE;

-- RLS helper functions for org-based access (also in the `private` schema)
CREATE OR REPLACE FUNCTION private.user_in_school_org(p_school_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_members om
    JOIN schools s ON s.org_id = om.org_id
    WHERE s.id = p_school_id AND om.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION private.user_is_org_member(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_members WHERE org_id = p_org_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION private.user_role_in_school_org(p_school_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT om.role FROM org_members om
  JOIN schools s ON s.org_id = om.org_id
  WHERE s.id = p_school_id AND om.user_id = auth.uid()
  LIMIT 1;
$$;

-- RLS: organizations + org_members
CREATE POLICY "Org members can view organization"
  ON organizations FOR SELECT
  USING (private.user_is_org_member(id));

CREATE POLICY "Org members can view memberships"
  ON org_members FOR SELECT
  USING (private.user_is_org_member(org_id));

-- Updated RLS: schools SELECT includes org members
DROP POLICY IF EXISTS "Users select own school" ON schools;
CREATE POLICY "Users select own school"
  ON schools FOR SELECT
  USING (owner_id = auth.uid() OR private.user_in_school_org(id));

-- Updated RLS: all child tables split into SELECT (org-wide) + write (owner-only)
-- See apply_migration for full policy definitions (active_timeline, display_settings,
-- templates, tasks, weekly_schedules, custom_themes, display_sessions, subscriptions)

-- Data migration: create orgs for existing schools
DO $$
DECLARE
  school_rec RECORD;
  new_org_id uuid;
BEGIN
  FOR school_rec IN SELECT id, owner_id, school_name FROM schools WHERE org_id IS NULL
  LOOP
    INSERT INTO organizations (name) VALUES (school_rec.school_name)
    RETURNING id INTO new_org_id;
    UPDATE schools SET org_id = new_org_id WHERE id = school_rec.id;
    INSERT INTO org_members (org_id, user_id, role)
    VALUES (new_org_id, school_rec.owner_id, 'teacher')
    ON CONFLICT (org_id, user_id) DO NOTHING;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- RLS helper EXECUTE grants — DO NOT REVOKE from authenticated/anon.
--
-- An RLS policy expression is evaluated with the privileges of the role running
-- the query (authenticated/anon), NOT the policy/function owner. So any function
-- referenced inside a USING/WITH CHECK expression must be EXECUTE-able by that
-- role — even SECURITY DEFINER functions (DEFINER only changes the role *inside*
-- the body; the caller still needs EXECUTE to invoke it). The roles also need
-- USAGE on the `private` schema (granted above).
--
-- History: a "security advisor" pass once revoked EXECUTE from authenticated to
-- silence the "SECURITY DEFINER function callable via RPC" lint. That broke every
-- org-aware policy with "42501 permission denied for function ...". The durable
-- fix is to keep the functions in the non-exposed `private` schema (so the lint
-- no longer fires) AND keep these grants. They only report facts about the
-- current auth.uid(), so granting EXECUTE leaks nothing.
GRANT EXECUTE ON FUNCTION private.user_is_org_member(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_in_school_org(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_owns_school(uuid)        TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_role_in_school_org(uuid) TO authenticated;

-- check_contact_rate_limit(text,text) backs the contact_messages INSERT policies
-- (landing-page form), so anon + authenticated need EXECUTE on it too. It is
-- defined in a later migration; grant only if present.
DO $$
BEGIN
  IF to_regprocedure('private.check_contact_rate_limit(text,text)') IS NOT NULL THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION private.check_contact_rate_limit(text,text) TO anon, authenticated';
  END IF;
END $$;
