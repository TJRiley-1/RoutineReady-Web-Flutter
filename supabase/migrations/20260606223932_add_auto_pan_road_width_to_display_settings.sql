
ALTER TABLE display_settings
  ADD COLUMN IF NOT EXISTS auto_pan_road_width int NOT NULL DEFAULT 40;
