-- Passthrough from int_user_segments_windowed.
-- One row per user per nutrient. Snapshot of each user's intake classification
-- across three windows: last day, last 7 days, last 30 days.
-- Grain: user_id + nutrient_id.

with

int_user_segments_windowed as (

    select
        user_id,
        nutrient_id,
        reference_date,
        last_day_g,
        last_7d_avg_g,
        last_30d_avg_g,
        threshold_g,
        threshold_type,
        segment_label,
        is_flagged_last_day,
        is_flagged_last_7d,
        is_flagged_last_30d
    from {{ ref('int_user_segments_windowed') }}

)

select
    user_id,
    nutrient_id,
    reference_date,
    last_day_g,
    last_7d_avg_g,
    last_30d_avg_g,
    threshold_g,
    threshold_type,
    segment_label,
    is_flagged_last_day,
    is_flagged_last_7d,
    is_flagged_last_30d
from int_user_segments_windowed
