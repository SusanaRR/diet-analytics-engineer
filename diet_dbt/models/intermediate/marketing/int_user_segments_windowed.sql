-- Computes intake averages over three windows (last day, last 7 days, last 30 days)
-- per user per nutrient, then classifies each window against recommended thresholds.
-- Protein threshold is personalised (weight_kg x 0.8) inline, consistent with
-- int_user_nutrient_segments.
-- Grain: user_id + nutrient_id (current snapshot, no date dimension).

with

int_daily_nutrient_intake as (

    select
        user_id,
        nutrient_id,
        logged_date,
        daily_value_g
    from {{ ref('int_daily_nutrient_intake') }}
    where logged_date >= current_date - interval '30 days'

),

last_dates as (

    select
        user_id,
        max(logged_date) as max_date
    from int_daily_nutrient_intake
    group by user_id

),

int_users_with_bmi as (

    select
        user_id,
        weight_kg
    from {{ ref('int_users_with_bmi') }}

),

nutrient_daily_targets as (

    select
        nutrient_id,
        recommended_daily_g,
        threshold_type,
        segment_label
    from {{ ref('nutrient_daily_targets') }}
    where segment_label is not null

),

windowed as (

    select
        int_daily_nutrient_intake.user_id,
        int_daily_nutrient_intake.nutrient_id,
        last_dates.max_date                                              as reference_date,
        max(case
            when int_daily_nutrient_intake.logged_date = last_dates.max_date
            then int_daily_nutrient_intake.daily_value_g
        end)                                                             as last_day_g,
        round(avg(case
            when int_daily_nutrient_intake.logged_date
                 >= last_dates.max_date - interval '6 days'
            then int_daily_nutrient_intake.daily_value_g
        end), 2)                                                         as last_7d_avg_g,
        round(avg(case
            when int_daily_nutrient_intake.logged_date
                 >= last_dates.max_date - interval '29 days'
            then int_daily_nutrient_intake.daily_value_g
        end), 2)                                                         as last_30d_avg_g
    from int_daily_nutrient_intake
    inner join last_dates
        on int_daily_nutrient_intake.user_id = last_dates.user_id
    group by
        int_daily_nutrient_intake.user_id,
        int_daily_nutrient_intake.nutrient_id,
        last_dates.max_date

),

with_threshold as (

    select
        windowed.user_id,
        windowed.nutrient_id,
        windowed.reference_date,
        windowed.last_day_g,
        windowed.last_7d_avg_g,
        windowed.last_30d_avg_g,
        case
            when windowed.nutrient_id = 1
            then round(int_users_with_bmi.weight_kg * 0.8, 1)
            else nutrient_daily_targets.recommended_daily_g
        end                                                              as threshold_g,
        nutrient_daily_targets.threshold_type,
        nutrient_daily_targets.segment_label
    from windowed
    inner join int_users_with_bmi
        on windowed.user_id = int_users_with_bmi.user_id
    inner join nutrient_daily_targets
        on windowed.nutrient_id = nutrient_daily_targets.nutrient_id

),

classified as (

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
        case
            when threshold_type = 'min' then last_day_g < threshold_g
            when threshold_type = 'max' then last_day_g > threshold_g
        end                                                              as is_flagged_last_day,
        case
            when threshold_type = 'min' then last_7d_avg_g < threshold_g
            when threshold_type = 'max' then last_7d_avg_g > threshold_g
        end                                                              as is_flagged_last_7d,
        case
            when threshold_type = 'min' then last_30d_avg_g < threshold_g
            when threshold_type = 'max' then last_30d_avg_g > threshold_g
        end                                                              as is_flagged_last_30d
    from with_threshold

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
from classified
