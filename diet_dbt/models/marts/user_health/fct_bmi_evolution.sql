{{
    config(
        materialized = 'incremental',
        unique_key   = 'weight_log_id'
    )
}}

-- Passthrough from int_users_bmi_history.
-- One row per weight log entry per user. Use recorded_date_id to join dim_date
-- for date attributes; join dim_users on user_id for user profile.
-- Grain: weight_log_id (user_id + recorded_at).

with

int_users_bmi_history as (

    select
        weight_log_id,
        user_id,
        weight_kg,
        height_cm,
        bmi,
        recorded_date_id
    from {{ ref('int_users_bmi_history') }}
    {% if is_incremental() %}
    where recorded_date_id > (select max(recorded_date_id) from {{ this }})
    {% endif %}

)

select
    weight_log_id,
    user_id,
    weight_kg,
    height_cm,
    bmi,
    recorded_date_id
from int_users_bmi_history
