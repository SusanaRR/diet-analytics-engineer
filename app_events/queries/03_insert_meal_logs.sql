-- Insert generated meal log rows. `df` is the pandas DataFrame registered by the Python script.

INSERT INTO {database}.app_events.raw_meal_logs (user_id, breakfast, lunch, dinner, logged_at)
SELECT user_id, breakfast, lunch, dinner, logged_at FROM df;
