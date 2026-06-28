-- Daily nutrient segment classification per user. Passthrough from
-- int_user_nutrient_segments. One row per user per nutrient per day.
-- Grain: user_id + nutrient_id + logged_date.
-- Incremental: appends new dates on each daily run; --full-refresh rebuilds from scratch.

{{
    config(
        materialized = 'incremental',
        unique_key   = ['user_id', 'nutrient_id', 'logged_date']
    )
}}

with

int_user_nutrient_segments as (

    select
        user_id,
        nutrient_id,
        logged_date,
        logged_date_id,
        daily_value_g,
        threshold_g,
        threshold_type,
        segment_label,
        is_flagged
    from {{ ref('int_user_nutrient_segments') }}

)

select
    user_id,
    nutrient_id,
    logged_date,
    logged_date_id,
    daily_value_g,
    threshold_g,
    threshold_type,
    segment_label,
    is_flagged
from int_user_nutrient_segments
{% if is_incremental() %}
    where logged_date > (select max(logged_date) from {{ this }})
{% endif %}
