-- Insert raw food JSON records into raw_foods, one row per food.

INSERT INTO {database}.usda.raw_foods (fdc_id, raw_json)
VALUES ($fdc_id, $raw_json);
