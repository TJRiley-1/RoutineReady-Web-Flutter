
-- Fix P0 #2: contact_messages rate-limit RLS bug
-- The existing policies compare cm.name = cm.name (always true) instead of comparing against the NEW row
-- Drop and recreate both policies with correct rate limiting

DROP POLICY IF EXISTS "Anon can insert contact messages" ON contact_messages;
DROP POLICY IF EXISTS "Authenticated can insert contact messages" ON contact_messages;

CREATE POLICY "Anon can insert contact messages" ON contact_messages
  FOR INSERT TO anon
  WITH CHECK (
    (SELECT count(*) FROM contact_messages cm
     WHERE cm.name = name
       AND cm.school = school
       AND cm.created_at > (now() - interval '1 minute')
    ) < 5
  );

CREATE POLICY "Authenticated can insert contact messages" ON contact_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT count(*) FROM contact_messages cm
     WHERE cm.name = name
       AND cm.school = school
       AND cm.created_at > (now() - interval '1 minute')
    ) < 5
  );

-- Fix P1 #6: Add explicit subscription write policies
-- Only service role (edge functions / webhooks) should write subscriptions
-- Authenticated users should NOT be able to INSERT/UPDATE/DELETE their own subscriptions directly

CREATE POLICY "Service role can manage subscriptions" ON subscriptions
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
