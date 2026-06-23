{{
    config(
        materialized = 'incremental',
        unique_key   = ['user_id', 'meal_id', 'fdc_id', 'logged_date']
    )
}}

-- One row per food item logged per user per meal per day.
-- Grain: user_id + meal_id + fdc_id + logged_date.
-- Join dim_foods on fdc_id for food descriptions; join meals seed on meal_id for meal names.

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
    {% if is_incremental() %}
    where logged_date > (select max(logged_date) from {{ this }})
    {% endif %}

)

select
    user_id,
    meal_id,
    fdc_id,
    grams,
    logged_date,
    logged_date_id
from int_meal_logs_unpivoted
