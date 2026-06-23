-- Normalises recorded_at to UTC first (TIMESTAMPTZ → plain TIMESTAMP via AT TIME ZONE),
-- then generates weight_log_id as a surrogate key from user_id + weight_kg + recorded_at
-- (UTC-normalised) using dbt_utils.generate_surrogate_key. Normalising before hashing
-- ensures the key is stable regardless of the original timezone offset in the source.
-- recorded_date_id is derived in int_users_bmi_history, not here — date_id derivation
-- belongs in the intermediate layer per project conventions.

with

source as (

    select
        user_id,
        weight_kg,
        recorded_at
    from {{ ref('weight_logs') }}

),

converted as (

    select
        user_id,
        cast(weight_kg as float)                                              as weight_kg,
        cast(recorded_at as timestamptz) at time zone 'UTC'                  as recorded_at
    from source

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['user_id', 'weight_kg', 'recorded_at']) }} as weight_log_id,
        user_id,
        weight_kg,
        recorded_at
    from converted

)

select
    weight_log_id,
    user_id,
    weight_kg,
    recorded_at
from renamed
