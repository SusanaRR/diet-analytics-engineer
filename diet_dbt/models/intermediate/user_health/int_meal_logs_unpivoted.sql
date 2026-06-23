-- Unnests breakfast, lunch, and dinner arrays from stg_app_events__meal_logs
-- into long format and joins the meals seed to resolve meal_name to meal_id.
-- Derives logged_date and logged_date_id. Empty arrays produce no rows implicitly.
-- Grain: user_id + meal_id + fdc_id + logged_date.
-- unnest() on an empty array produces no rows, so meals a user did not log
-- are already filtered out implicitly. The WHERE clause below makes this
-- explicit and also guards against any null items that could slip through.

with

stg_app_events__meal_logs as (

    select
        user_id,
        breakfast,
        lunch,
        dinner,
        logged_at
    from {{ ref('stg_app_events__meal_logs') }}

),

meals as (

    select
        meal_id,
        meal_name
    from {{ ref('meals') }}

),

unpivoted as (

    select user_id, logged_at, 'breakfast' as meal_name, unnest(breakfast) as item
    from stg_app_events__meal_logs
    union all
    select user_id, logged_at, 'lunch' as meal_name, unnest(lunch) as item
    from stg_app_events__meal_logs
    union all
    select user_id, logged_at, 'dinner' as meal_name, unnest(dinner) as item
    from stg_app_events__meal_logs

),

meal_items as (

    select
        unpivoted.user_id,
        meals.meal_id,
        unpivoted.item.fdc_id                                     as fdc_id,
        unpivoted.item.grams                                      as grams,
        cast(unpivoted.logged_at as date)                         as logged_date,
        {{ date_to_id('cast(unpivoted.logged_at as date)') }}    as logged_date_id
    from unpivoted
    inner join meals
        on unpivoted.meal_name = meals.meal_name
    where unpivoted.item.fdc_id is not null
        and unpivoted.item.grams is not null

)

select
    user_id,
    meal_id,
    fdc_id,
    grams,
    logged_date,
    logged_date_id
from meal_items
