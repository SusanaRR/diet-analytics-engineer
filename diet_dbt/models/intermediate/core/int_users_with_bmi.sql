-- Grain: user_id.
-- Sources: stg_app_events__users, stg_app_events__weight_logs, bmi_categories seed.
-- Joins users to their most recent weight log and classifies BMI via a range
-- join to the bmi_categories seed. weight_kg reflects the latest weigh-in.

with

stg_app_events__users as (

    select
        user_id,
        country,
        birth_date,
        height_cm,
        registered_at
    from {{ ref('stg_app_events__users') }}

),

latest_weight as (

    select
        user_id,
        weight_kg
    from {{ ref('stg_app_events__weight_logs') }}
    qualify row_number() over (partition by user_id order by recorded_at desc) = 1

),

bmi_categories as (

    select
        min_bmi,
        max_bmi,
        category
    from {{ ref('bmi_categories') }}

),

bmi_calc as (

    select
        stg_app_events__users.user_id,
        stg_app_events__users.country,
        stg_app_events__users.birth_date,
        latest_weight.weight_kg,
        stg_app_events__users.height_cm,
        stg_app_events__users.registered_at,
        {{ calculate_bmi('latest_weight.weight_kg', 'stg_app_events__users.height_cm') }} as bmi,
        {{ date_to_id('cast(stg_app_events__users.registered_at as date)') }}             as registered_date_id
    from stg_app_events__users
    inner join latest_weight
        on stg_app_events__users.user_id = latest_weight.user_id

),

final as (

    select
        bmi_calc.user_id,
        bmi_calc.country,
        bmi_calc.birth_date,
        bmi_calc.weight_kg,
        bmi_calc.height_cm,
        bmi_calc.bmi,
        bmi_calc.registered_date_id,
        bmi_categories.category as bmi_category
    from bmi_calc
    inner join bmi_categories
        on bmi_calc.bmi >= bmi_categories.min_bmi
        and bmi_calc.bmi < bmi_categories.max_bmi

)

select
    user_id,
    country,
    birth_date,
    weight_kg,
    height_cm,
    bmi,
    registered_date_id,
    bmi_category
from final
