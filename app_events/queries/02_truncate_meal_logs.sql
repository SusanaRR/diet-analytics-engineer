-- Truncate raw meal logs before inserting today's data.
-- This ensures idempotency: if the daily script runs twice, only one day's rows are inserted.
-- Historical data is safe in the incremental mart tables (fct_meal_logs, fct_meal_log_nutrients).

TRUNCATE {database}.app_events.raw_meal_logs;
