-- One row per tracked macro nutrient. Passthrough from the nutrients seed.
-- Maps nutrient_id and USDA nutrient code to a human-readable name and unit.
-- Grain: nutrient_id.

with

source as (

    select
        nutrient_id,
        usda_nutrient_id,
        nutrient_name,
        unit
    from {{ ref('nutrients') }}

)

select
    nutrient_id,
    usda_nutrient_id,
    nutrient_name,
    unit
from source
