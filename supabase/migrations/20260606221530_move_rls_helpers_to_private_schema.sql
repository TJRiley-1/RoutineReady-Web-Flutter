
-- Move RLS helper functions out of the API-exposed `public` schema into a
-- `private` schema so the Supabase security advisor stops flagging them as
-- "SECURITY DEFINER function callable via /rest/v1/rpc", while keeping them
-- usable by RLS policies. RLS still executes them as the querying role, so the
-- roles keep EXECUTE + USAGE on the private schema. The `private` schema is not
-- in PostgREST's exposed schema list, so these are no longer reachable as RPCs.

-- 1. Private schema (not exposed via the REST API)
CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO authenticated, anon;

-- 2. Recreate helpers in private (identical bodies; search_path=public so the
--    unqualified table refs resolve to public.*)
CREATE OR REPLACE FUNCTION private.user_owns_school(p_school_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id AND owner_id = auth.uid());
$$;

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
  SELECT EXISTS (SELECT 1 FROM org_members WHERE org_id = p_org_id AND user_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION private.user_role_in_school_org(p_school_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT om.role FROM org_members om
  JOIN schools s ON s.org_id = om.org_id
  WHERE s.id = p_school_id AND om.user_id = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.check_contact_rate_limit(p_name text, p_school text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*) < 5 FROM contact_messages
  WHERE name = p_name AND school = p_school
    AND created_at > (now() - interval '1 minute');
$$;

-- 3. Explicit EXECUTE grants (revoke default PUBLIC, grant only what's needed)
REVOKE ALL ON FUNCTION private.user_owns_school(uuid)            FROM PUBLIC;
REVOKE ALL ON FUNCTION private.user_in_school_org(uuid)          FROM PUBLIC;
REVOKE ALL ON FUNCTION private.user_is_org_member(uuid)          FROM PUBLIC;
REVOKE ALL ON FUNCTION private.user_role_in_school_org(uuid)     FROM PUBLIC;
REVOKE ALL ON FUNCTION private.check_contact_rate_limit(text,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION private.user_owns_school(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_in_school_org(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_is_org_member(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION private.user_role_in_school_org(uuid)     TO authenticated;
GRANT EXECUTE ON FUNCTION private.check_contact_rate_limit(text,text) TO anon, authenticated;

-- 4. Repoint every policy to the private-qualified functions (ALTER = no gap)
-- active_timeline
ALTER POLICY "Org members read timeline"   ON active_timeline USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));
ALTER POLICY "Owner deletes timeline"      ON active_timeline USING (private.user_owns_school(school_id));
ALTER POLICY "Owner manages timeline write" ON active_timeline WITH CHECK (private.user_owns_school(school_id));
ALTER POLICY "Owner updates timeline"      ON active_timeline USING (private.user_owns_school(school_id)) WITH CHECK (private.user_owns_school(school_id));

-- custom_themes
ALTER POLICY "Org members read custom themes"    ON custom_themes USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));
ALTER POLICY "Owner deletes custom themes"       ON custom_themes USING (private.user_owns_school(school_id));
ALTER POLICY "Owner manages custom themes write" ON custom_themes WITH CHECK (private.user_owns_school(school_id));
ALTER POLICY "Owner updates custom themes"       ON custom_themes USING (private.user_owns_school(school_id)) WITH CHECK (private.user_owns_school(school_id));

-- display_sessions
ALTER POLICY "Org members manage sessions" ON display_sessions USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id)) WITH CHECK (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));

-- display_settings
ALTER POLICY "Org members read display settings"    ON display_settings USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));
ALTER POLICY "Owner deletes display settings"       ON display_settings USING (private.user_owns_school(school_id));
ALTER POLICY "Owner manages display settings write" ON display_settings WITH CHECK (private.user_owns_school(school_id));
ALTER POLICY "Owner updates display settings"       ON display_settings USING (private.user_owns_school(school_id)) WITH CHECK (private.user_owns_school(school_id));

-- templates
ALTER POLICY "Org members read templates"    ON templates USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));
ALTER POLICY "Owner deletes templates"       ON templates USING (private.user_owns_school(school_id));
ALTER POLICY "Owner manages templates write" ON templates WITH CHECK (private.user_owns_school(school_id));
ALTER POLICY "Owner updates templates"       ON templates USING (private.user_owns_school(school_id)) WITH CHECK (private.user_owns_school(school_id));

-- weekly_schedules
ALTER POLICY "Org members read weekly schedules"    ON weekly_schedules USING (private.user_owns_school(school_id) OR private.user_in_school_org(school_id));
ALTER POLICY "Owner deletes weekly schedules"       ON weekly_schedules USING (private.user_owns_school(school_id));
ALTER POLICY "Owner manages weekly schedules write" ON weekly_schedules WITH CHECK (private.user_owns_school(school_id));
ALTER POLICY "Owner updates weekly schedules"       ON weekly_schedules USING (private.user_owns_school(school_id)) WITH CHECK (private.user_owns_school(school_id));

-- tasks (scoped via templates subquery)
ALTER POLICY "Org members read tasks"    ON tasks USING (template_id IN (SELECT templates.id FROM templates WHERE private.user_owns_school(templates.school_id) OR private.user_in_school_org(templates.school_id)));
ALTER POLICY "Owner deletes tasks"       ON tasks USING (template_id IN (SELECT templates.id FROM templates WHERE private.user_owns_school(templates.school_id)));
ALTER POLICY "Owner manages tasks write" ON tasks WITH CHECK (template_id IN (SELECT templates.id FROM templates WHERE private.user_owns_school(templates.school_id)));
ALTER POLICY "Owner updates tasks"       ON tasks USING (template_id IN (SELECT templates.id FROM templates WHERE private.user_owns_school(templates.school_id))) WITH CHECK (template_id IN (SELECT templates.id FROM templates WHERE private.user_owns_school(templates.school_id)));

-- org_members / organizations / schools / subscriptions
ALTER POLICY "Org members can view memberships"  ON org_members   USING (private.user_is_org_member(org_id));
ALTER POLICY "Org members can view organization" ON organizations USING (private.user_is_org_member(id));
ALTER POLICY "Users select own school"           ON schools       USING (owner_id = auth.uid() OR private.user_in_school_org(id));
ALTER POLICY "Users read own subscription"       ON subscriptions USING (user_id = auth.uid() OR school_id IN (SELECT schools.id FROM schools WHERE schools.owner_id = auth.uid()) OR (org_id IS NOT NULL AND private.user_is_org_member(org_id)));

-- contact_messages
ALTER POLICY "Anon can insert contact messages"          ON contact_messages WITH CHECK (private.check_contact_rate_limit(name, school));
ALTER POLICY "Authenticated can insert contact messages" ON contact_messages WITH CHECK (private.check_contact_rate_limit(name, school));

-- 5. Drop the now-unreferenced public copies (no CASCADE: fails loudly if any
--    dependency was missed)
DROP FUNCTION public.user_owns_school(uuid);
DROP FUNCTION public.user_in_school_org(uuid);
DROP FUNCTION public.user_is_org_member(uuid);
DROP FUNCTION public.user_role_in_school_org(uuid);
DROP FUNCTION public.check_contact_rate_limit(text,text);
