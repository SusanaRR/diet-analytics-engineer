-- Classifies each user per nutrient per day against recommended thresholds.
-- Protein threshold is personalised: weight_kg * 0.8 (calculated inline from
-- int_users_with_bmi to avoid referencing the dim_users mart).
-- All other thresholds are generic daily values from nutrient_daily_targets.
-- Grain: user_id + nutrient_id + logged_date.

with

int_daily_nutrient_intake as (

    select
        user_id,
        nutrient_id,
        logged_date,
        logged_date_id,
        daily_value_g
    from {{ ref('int_daily_nutrient_intake') }}

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

with_threshold as (

    select
        int_daily_nutrient_intake.user_id,
        int_daily_nutrient_intake.nutrient_id,
        int_daily_nutrient_intake.logged_date,
        int_daily_nutrient_intake.logged_date_id,
        round(int_daily_nutrient_intake.daily_value_g, 2)                as daily_value_g,
        case
            when int_daily_nutrient_intake.nutrient_id = 1
            then round(int_users_with_bmi.weight_kg * 0.8, 1)
            else nutrient_daily_targets.recommended_daily_g
        end                                                              as threshold_g,
        nutrient_daily_targets.threshold_type,
        nutrient_daily_targets.segment_label
    from int_daily_nutrient_intake
    inner join int_users_with_bmi
        on int_daily_nutrient_intake.user_id = int_users_with_bmi.user_id
    inner join nutrient_daily_targets
        on int_daily_nutrient_intake.nutrient_id = nutrient_daily_targets.nutrient_id

),

classified as (

    select
        user_id,
        nutrient_id,
        logged_date,
        logged_date_id,
        daily_value_g,
        threshold_g,
        threshold_type,
        segment_label,
        case
            when threshold_type = 'min' then daily_value_g < threshold_g
            when threshold_type = 'max' then daily_value_g > threshold_g
        end                                                              as is_flagged
    from with_threshold

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
from classified
