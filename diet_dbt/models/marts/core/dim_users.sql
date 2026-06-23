-- One row per user. Derives BMI category and recommended protein from
-- int_users_with_bmi. weight_kg reflects the user's most recent weigh-in.
-- age is intentionally excluded — it changes daily and should be derived
-- at query time from birth_date in the BI layer.
-- Grain: user_id.

with

int_users_with_bmi as (

    select
        user_id,
        country,
        birth_date,
        weight_kg,
        height_cm,
        bmi,
        bmi_category,
        registered_date_id
    from {{ ref('int_users_with_bmi') }}

),

final as (

    select
        user_id,
        country,
        birth_date,
        weight_kg,
        height_cm,
        bmi,
        bmi_category,
        round(weight_kg * 0.8, 1) as recommended_protein_g,
        registered_date_id
    from int_users_with_bmi

)

select
    user_id,
    country,
    birth_date,
    weight_kg,
    height_cm,
    bmi,
    bmi_category,
    recommended_protein_g,
    registered_date_id
from final
