-- int_food_nutrients_pivoted_to_foods.sql

{% set macro_nutrients = {
    '203': 'protein_g',
    '204': 'fat_g',
    '205': 'carbohydrate_g',
    '291': 'fiber_g',
    '269': 'total_sugar_g'
} %}

with

stg_usda__food_nutrients as (

    select
        fdc_id,
        description,
        publication_date,
        raw_json,
        loaded_at
    from {{ ref('stg_usda__food_nutrients') }}

),

food_extracted_nutrients as (

    select
        fdc_id,
        description,
        publication_date,
        loaded_at,
        value ->> 'number' as usda_nutrient_id,
        try_cast(value ->> 'amount' as double) as nutrient_amount
    from stg_usda__food_nutrients, json_each(raw_json, '$.foodNutrients')

),

pivot_and_aggregate_nutrients_to_food_grain as (

    select
        fdc_id,
        description,
        {{ date_to_id('publication_date') }}             as publication_date_id,
        loaded_at,
        {{ date_to_id('cast(loaded_at as date)') }}     as loaded_date_id,
        {% for number, column_name in macro_nutrients.items() %}
        coalesce(max(case when usda_nutrient_id = '{{ number }}' then nutrient_amount end), 0) as {{ column_name }}{{ "," if not loop.last }}
        {% endfor %}
    from food_extracted_nutrients
    group by fdc_id, description, publication_date, loaded_at

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
from pivot_and_aggregate_nutrients_to_food_grain
