-- Null strategy:
-- user_id and logged_at are required — nulls here are caught by not_null tests.
-- Individual meal arrays (breakfast, lunch, dinner) can be null or empty — a user
-- may log only one or two meals in a day. No not_null test is applied per column.
-- However, at least one meal must be logged per row. This is enforced by a custom
-- singular test: tests/assert_meal_logs_have_at_least_one_meal.sql
-- Rows where all three arrays are null or empty indicate a bad record and should fail.
--
-- Null arrays are coalesced to empty arrays in the renamed CTE. This ensures
-- unnest() in int_meal_logs_unpivoted always receives an array — empty arrays
-- safely produce no rows, while unnest(NULL) can behave unexpectedly in DuckDB.
-- A skipped meal simply contributes no nutrient data downstream.
--
-- logged_at is preserved as TIMESTAMPTZ normalised to UTC. Date truncation and
-- date_id derivation happen in the intermediate layer.

with

source as (

    select
        user_id,
        breakfast,
        lunch,
        dinner,
        logged_at
    from {{ source('app_events', 'raw_meal_logs') }}

),

renamed as (

    select
        user_id,
        coalesce(breakfast, []) as breakfast,
        coalesce(lunch,    []) as lunch,
        coalesce(dinner,   []) as dinner,
        cast(logged_at as timestamptz) at time zone 'UTC' as logged_at
    from source

)

select
    user_id,
    breakfast,
    lunch,
    dinner,
    logged_at
from renamed
