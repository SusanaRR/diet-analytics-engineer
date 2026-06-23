-- Fetch real food ids from raw_foods so meal log generation can run before dbt.
-- Simplification: fdc_id is already a direct column on raw_foods, so no dbt run
-- is needed before generating synthetic meal logs. In a production setup this
-- would query dim_foods to ensure only validated, transformed foods are referenced.

SELECT fdc_id FROM {database}.usda.raw_foods;

