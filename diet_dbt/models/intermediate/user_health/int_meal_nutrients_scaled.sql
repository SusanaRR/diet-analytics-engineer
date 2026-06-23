-- Joins meal log items to food nutrient data and scales each nutrient
-- by the actual serving size logged: nutrient_per_100g * grams / 100.
-- One row per user per meal per food item per day.

{% set nutrients = ['protein_g', 'fat_g', 'carbohydrate_g', 'fiber_g', 'total_sugar_g'] %}

with

int_meal_logs_unpivoted as (

    select
        user_id,
        meal_id,
        fdc_id,
        grams,
        logged_date,
        logged_date_id
    from {{ ref('int_meal_logs_unpivoted') }}

),

int_food_nutrients_pivoted_to_foods as (

    select
        fdc_id,
        {% for nutrient in nutrients %}
        {{ nutrient }}{{ "," if not loop.last }}
        {% endfor %}
    from {{ ref('int_food_nutrients_pivoted_to_foods') }}

),

scaled as (

    select
        int_meal_logs_unpivoted.user_id,
        int_meal_logs_unpivoted.meal_id,
        int_meal_logs_unpivoted.logged_date,
        int_meal_logs_unpivoted.logged_date_id,
        {% for nutrient in nutrients %}
        int_food_nutrients_pivoted_to_foods.{{ nutrient }} * int_meal_logs_unpivoted.grams / 100.0 as {{ nutrient }}{{ "," if not loop.last }}
        {% endfor %}
    from int_meal_logs_unpivoted
    inner join int_food_nutrients_pivoted_to_foods
        on int_meal_logs_unpivoted.fdc_id = int_food_nutrients_pivoted_to_foods.fdc_id

)

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
from scaled
