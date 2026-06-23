{{
    config(
        materialized = 'incremental',
        unique_key   = ['user_id', 'meal_id', 'nutrient_id', 'logged_date']
    )
}}

-- Aggregates scaled nutrient intake per user per meal per day and pivots to
-- long format. nutrient_id is a FK to dim_nutrients.
-- Grain: user_id + meal_id + nutrient_id + logged_date.

with

int_meal_nutrients_scaled as (

    select
        user_id,
        meal_id,
        logged_date,
        logged_date_id,
        protein_g,
        fat_g,
        carbohydrate_g,
        fiber_g,
        total_sugar_g
    from {{ ref('int_meal_nutrients_scaled') }}
    {% if is_incremental() %}
    where logged_date > (select max(logged_date) from {{ this }})
    {% endif %}

),

aggregated as (

    select
        user_id,
        meal_id,
        logged_date,
        logged_date_id,
        sum(protein_g)      as protein_g,
        sum(fat_g)          as fat_g,
        sum(carbohydrate_g) as carbohydrate_g,
        sum(fiber_g)        as fiber_g,
        sum(total_sugar_g)  as total_sugar_g
    from int_meal_nutrients_scaled
    group by user_id, meal_id, logged_date, logged_date_id

),

-- nutrient_id values map to nutrients.csv: 1=protein, 2=fat, 3=carbohydrate, 4=fiber, 5=total_sugar
long_format as (

    select user_id, meal_id, logged_date, logged_date_id, 1 as nutrient_id, protein_g      as value_g from aggregated
    union all
    select user_id, meal_id, logged_date, logged_date_id, 2 as nutrient_id, fat_g          as value_g from aggregated
    union all
    select user_id, meal_id, logged_date, logged_date_id, 3 as nutrient_id, carbohydrate_g as value_g from aggregated
    union all
    select user_id, meal_id, logged_date, logged_date_id, 4 as nutrient_id, fiber_g        as value_g from aggregated
    union all
    select user_id, meal_id, logged_date, logged_date_id, 5 as nutrient_id, total_sugar_g  as value_g from aggregated

)

select
    user_id,
    meal_id,
    nutrient_id,
    logged_date,
    logged_date_id,
    value_g
from long_format
