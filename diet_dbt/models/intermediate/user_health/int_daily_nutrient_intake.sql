-- Aggregates scaled nutrient intake from int_meal_nutrients_scaled to daily
-- totals per user per nutrient. Building block for int_user_nutrient_segments.
-- Grain: user_id + nutrient_id + logged_date.

with

int_meal_nutrients_scaled as (

    select
        user_id,
        logged_date,
        logged_date_id,
        protein_g,
        fat_g,
        carbohydrate_g,
        fiber_g,
        total_sugar_g
    from {{ ref('int_meal_nutrients_scaled') }}
    where logged_date >= current_date - interval '365 days'

),

-- nutrient_id values map to nutrients.csv: 1=protein, 2=fat, 3=carbohydrate, 4=fiber, 5=total_sugar
long_format as (

    select user_id, logged_date, logged_date_id, 1 as nutrient_id, protein_g      as value_g from int_meal_nutrients_scaled
    union all
    select user_id, logged_date, logged_date_id, 2 as nutrient_id, fat_g          as value_g from int_meal_nutrients_scaled
    union all
    select user_id, logged_date, logged_date_id, 3 as nutrient_id, carbohydrate_g as value_g from int_meal_nutrients_scaled
    union all
    select user_id, logged_date, logged_date_id, 4 as nutrient_id, fiber_g        as value_g from int_meal_nutrients_scaled
    union all
    select user_id, logged_date, logged_date_id, 5 as nutrient_id, total_sugar_g  as value_g from int_meal_nutrients_scaled

),

daily_totals as (

    select
        user_id,
        nutrient_id,
        logged_date,
        logged_date_id,
        sum(value_g) as daily_value_g
    from long_format
    group by user_id, nutrient_id, logged_date, logged_date_id

)

select
    user_id,
    nutrient_id,
    logged_date,
    logged_date_id,
    daily_value_g
from daily_totals
