-- Every row in stg_app_events__meal_logs must have at least one meal logged.
-- Individual meals (breakfast, lunch, dinner) can be null or empty — a user
-- may skip meals — but a log entry with all three empty is invalid.
-- This test returns rows that violate the rule; dbt fails if any rows are returned.

select
    user_id,
    logged_at
from {{ ref('stg_app_events__meal_logs') }}
where
    (breakfast is null or len(breakfast) = 0)
    and (lunch    is null or len(lunch)    = 0)
    and (dinner   is null or len(dinner)   = 0)
