-- One row per meal type. Passthrough from the meals seed.
-- Grain: meal_id.

with

source as (

    select
        meal_id,
        meal_name
    from {{ ref('meals') }}

)

select
    meal_id,
    meal_name
from source
