-- Add an explicit display-order column to templates so saved templates can be
-- reordered, instead of relying on created_at (which is fragile under the
-- same-millisecond bulk re-insert that every save performs).
ALTER TABLE templates
  ADD COLUMN IF NOT EXISTS position integer NOT NULL DEFAULT 0;

-- Backfill existing rows so the first load (before any save writes positions)
-- keeps the current created_at order. Number each school's rows 0..n-1.
WITH ordered AS (
  SELECT id,
         row_number() OVER (PARTITION BY school_id ORDER BY created_at) - 1 AS pos
  FROM templates
)
UPDATE templates t
SET position = ordered.pos
FROM ordered
WHERE t.id = ordered.id;
