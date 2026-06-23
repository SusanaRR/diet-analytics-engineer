-- One row per food. Passthrough from int_food_nutrients_pivoted_to_foods.
-- Nutrient values are per 100g serving.
-- Grain: fdc_id.

with

int_food_nutrients_pivoted_to_foods as (

    select
        fdc_id,
        description,
        publication_date_id,
        loaded_date_id,
        protein_g,
        fat_g,
        carbohydrate_g,
        fiber_g,
        total_sugar_g
    from {{ ref('int_food_nutrients_pivoted_to_foods') }}

)

select
    fdc_id,
    description,
    publication_date_id,
    loaded_date_id,
    protein_g,
    fat_g,
    carbohydrate_g,
    fiber_g,
    total_sugar_g
from int_food_nutrients_pivoted_to_foods
