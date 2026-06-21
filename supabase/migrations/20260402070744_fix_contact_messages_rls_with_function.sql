
-- Create a helper function that receives the new row's values explicitly
CREATE OR REPLACE FUNCTION check_contact_rate_limit(p_name text, p_school text)
RETURNS boolean AS $$
  SELECT count(*) < 5
  FROM contact_messages
  WHERE name = p_name
    AND school = p_school
    AND created_at > (now() - interval '1 minute');
$$ LANGUAGE sql SECURITY DEFINER;

-- Drop the broken policies
DROP POLICY IF EXISTS "Anon can insert contact messages" ON contact_messages;
DROP POLICY IF EXISTS "Authenticated can insert contact messages" ON contact_messages;

-- Recreate with function call — name and school here reference the NEW row's columns
CREATE POLICY "Anon can insert contact messages" ON contact_messages
  FOR INSERT TO anon
  WITH CHECK (check_contact_rate_limit(name, school));

CREATE POLICY "Authenticated can insert contact messages" ON contact_messages
  FOR INSERT TO authenticated
  WITH CHECK (check_contact_rate_limit(name, school));
