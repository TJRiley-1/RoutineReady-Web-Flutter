
-- ═══════════════════════════════════════════════════════════════
-- Multi-Account School Organization Model
-- ═══════════════════════════════════════════════════════════════

-- 0. Ensure user_owns_school helper exists (from prior migration file)
CREATE OR REPLACE FUNCTION user_owns_school(p_school_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM schools WHERE id = p_school_id AND owner_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 1a. Organizations table
CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- 1b. Org members table
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

-- 1c. Add org_id to schools (nullable for backward compat)
ALTER TABLE schools ADD COLUMN IF NOT EXISTS org_id uuid REFERENCES organizations ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_schools_org_id ON schools(org_id);

-- 1d. Add org_id to subscriptions
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS org_id uuid REFERENCES organizations ON DELETE CASCADE;

-- 1e. RLS helper functions
CREATE OR REPLACE FUNCTION user_in_school_org(p_school_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_members om
    JOIN schools s ON s.org_id = om.org_id
    WHERE s.id = p_school_id AND om.user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION user_is_org_member(p_org_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_members WHERE org_id = p_org_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION user_role_in_school_org(p_school_id uuid)
RETURNS text AS $$
  SELECT om.role FROM org_members om
  JOIN schools s ON s.org_id = om.org_id
  WHERE s.id = p_school_id AND om.user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ═══════════════════════════════════════════════════════════════
-- 1f. RLS policies for new tables
-- ═══════════════════════════════════════════════════════════════

CREATE POLICY "Org members can view organization"
  ON organizations FOR SELECT
  USING (user_is_org_member(id));

CREATE POLICY "Org members can view memberships"
  ON org_members FOR SELECT
  USING (user_is_org_member(org_id));

-- ═══════════════════════════════════════════════════════════════
-- 1g. Update existing RLS policies for org-wide access
-- ═══════════════════════════════════════════════════════════════

-- ── schools ──
DROP POLICY IF EXISTS "Users select own school" ON schools;
CREATE POLICY "Users select own school"
  ON schools FOR SELECT
  USING (owner_id = auth.uid() OR user_in_school_org(id));

-- ── active_timeline ──
DROP POLICY IF EXISTS "Users manage own timeline" ON active_timeline;
CREATE POLICY "Org members read timeline"
  ON active_timeline FOR SELECT
  USING (user_owns_school(school_id) OR user_in_school_org(school_id));
CREATE POLICY "Owner manages timeline write"
  ON active_timeline FOR INSERT
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner updates timeline"
  ON active_timeline FOR UPDATE
  USING (user_owns_school(school_id))
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner deletes timeline"
  ON active_timeline FOR DELETE
  USING (user_owns_school(school_id));

-- ── display_settings ──
DROP POLICY IF EXISTS "Users manage own display settings" ON display_settings;
CREATE POLICY "Org members read display settings"
  ON display_settings FOR SELECT
  USING (user_owns_school(school_id) OR user_in_school_org(school_id));
CREATE POLICY "Owner manages display settings write"
  ON display_settings FOR INSERT
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner updates display settings"
  ON display_settings FOR UPDATE
  USING (user_owns_school(school_id))
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner deletes display settings"
  ON display_settings FOR DELETE
  USING (user_owns_school(school_id));

-- ── templates ──
DROP POLICY IF EXISTS "Users manage own templates" ON templates;
CREATE POLICY "Org members read templates"
  ON templates FOR SELECT
  USING (user_owns_school(school_id) OR user_in_school_org(school_id));
CREATE POLICY "Owner manages templates write"
  ON templates FOR INSERT
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner updates templates"
  ON templates FOR UPDATE
  USING (user_owns_school(school_id))
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner deletes templates"
  ON templates FOR DELETE
  USING (user_owns_school(school_id));

-- ── tasks ──
DROP POLICY IF EXISTS "Users manage own tasks" ON tasks;
CREATE POLICY "Org members read tasks"
  ON tasks FOR SELECT
  USING (
    template_id IN (
      SELECT id FROM templates WHERE user_owns_school(school_id) OR user_in_school_org(school_id)
    )
  );
CREATE POLICY "Owner manages tasks write"
  ON tasks FOR INSERT
  WITH CHECK (
    template_id IN (SELECT id FROM templates WHERE user_owns_school(school_id))
  );
CREATE POLICY "Owner updates tasks"
  ON tasks FOR UPDATE
  USING (template_id IN (SELECT id FROM templates WHERE user_owns_school(school_id)))
  WITH CHECK (template_id IN (SELECT id FROM templates WHERE user_owns_school(school_id)));
CREATE POLICY "Owner deletes tasks"
  ON tasks FOR DELETE
  USING (template_id IN (SELECT id FROM templates WHERE user_owns_school(school_id)));

-- ── weekly_schedules ──
DROP POLICY IF EXISTS "Users manage own weekly schedules" ON weekly_schedules;
CREATE POLICY "Org members read weekly schedules"
  ON weekly_schedules FOR SELECT
  USING (user_owns_school(school_id) OR user_in_school_org(school_id));
CREATE POLICY "Owner manages weekly schedules write"
  ON weekly_schedules FOR INSERT
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner updates weekly schedules"
  ON weekly_schedules FOR UPDATE
  USING (user_owns_school(school_id))
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner deletes weekly schedules"
  ON weekly_schedules FOR DELETE
  USING (user_owns_school(school_id));

-- ── custom_themes ──
DROP POLICY IF EXISTS "Users manage own custom themes" ON custom_themes;
CREATE POLICY "Org members read custom themes"
  ON custom_themes FOR SELECT
  USING (user_owns_school(school_id) OR user_in_school_org(school_id));
CREATE POLICY "Owner manages custom themes write"
  ON custom_themes FOR INSERT
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner updates custom themes"
  ON custom_themes FOR UPDATE
  USING (user_owns_school(school_id))
  WITH CHECK (user_owns_school(school_id));
CREATE POLICY "Owner deletes custom themes"
  ON custom_themes FOR DELETE
  USING (user_owns_school(school_id));

-- ── display_sessions ──
DROP POLICY IF EXISTS "Users manage own school sessions" ON display_sessions;
CREATE POLICY "Org members manage sessions"
  ON display_sessions FOR ALL
  USING (user_owns_school(school_id) OR user_in_school_org(school_id))
  WITH CHECK (user_owns_school(school_id) OR user_in_school_org(school_id));

-- ── subscriptions ──
DROP POLICY IF EXISTS "Users read own subscription" ON subscriptions;
CREATE POLICY "Users read own subscription"
  ON subscriptions FOR SELECT
  USING (
    user_id = auth.uid()
    OR school_id IN (SELECT id FROM schools WHERE owner_id = auth.uid())
    OR (org_id IS NOT NULL AND user_is_org_member(org_id))
  );

-- ═══════════════════════════════════════════════════════════════
-- 1h. Migrate existing data: create orgs for existing schools
-- ═══════════════════════════════════════════════════════════════
DO $$
DECLARE
  school_rec RECORD;
  new_org_id uuid;
BEGIN
  FOR school_rec IN SELECT id, owner_id, school_name FROM schools WHERE org_id IS NULL
  LOOP
    -- Create organization
    INSERT INTO organizations (name) VALUES (school_rec.school_name)
    RETURNING id INTO new_org_id;
    
    -- Link school to org
    UPDATE schools SET org_id = new_org_id WHERE id = school_rec.id;
    
    -- Add owner as teacher member
    INSERT INTO org_members (org_id, user_id, role)
    VALUES (new_org_id, school_rec.owner_id, 'teacher')
    ON CONFLICT (org_id, user_id) DO NOTHING;
  END LOOP;
END $$;
