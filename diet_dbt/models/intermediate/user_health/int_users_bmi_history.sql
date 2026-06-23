-- One row per weight log entry. Joins weight logs to user height (from
-- stg_app_events__users) and computes BMI at each recorded weight.
-- Building block for fct_bmi_evolution.
-- Grain: weight_log_id (user_id + recorded_at).

with

stg_app_events__weight_logs as (

    select
        weight_log_id,
        user_id,
        weight_kg,
        recorded_at
    from {{ ref('stg_app_events__weight_logs') }}

),

stg_app_events__users as (

    select
        user_id,
        height_cm
    from {{ ref('stg_app_events__users') }}

),

with_bmi as (

    select
        stg_app_events__weight_logs.weight_log_id,
        stg_app_events__weight_logs.user_id,
        stg_app_events__weight_logs.weight_kg,
        stg_app_events__users.height_cm,
        {{ calculate_bmi('stg_app_events__weight_logs.weight_kg', 'stg_app_events__users.height_cm') }} as bmi,
        {{ date_to_id('cast(stg_app_events__weight_logs.recorded_at as date)') }}                      as recorded_date_id
    from stg_app_events__weight_logs
    inner join stg_app_events__users
        on stg_app_events__weight_logs.user_id = stg_app_events__users.user_id

)

select
    weight_log_id,
    user_id,
    weight_kg,
    height_cm,
    bmi,
    recorded_date_id
from with_bmi
