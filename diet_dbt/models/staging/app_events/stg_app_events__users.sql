-- Privacy: user_name is not brought into the analytics warehouse.
-- It remains in the app's operational database, where it is used for
-- communications (emails, push notifications, etc.). The analytics layer
-- identifies users solely by user_id — no name, hashed or otherwise, is needed.
-- Under GDPR, names are personal data; keeping them out of the warehouse
-- entirely is safer than pseudonymising them.
--
-- Additional fields such as birth_date and height_cm may also require
-- explicit user consent before being collected and stored, depending on the
-- legal basis used (e.g. consent, contract, or legitimate interest). A data
-- privacy review should be conducted before this pipeline processes real user data.
--
-- Null strategy: all columns are required — no coalesce applied.
-- Nulls in any column should be caught by not_null tests and fail loudly.

with

source as (

    select
        user_id,
        country,
        birth_date,
        height_cm,
        registered_at
    from {{ ref('users') }}

),

renamed as (

    select
        user_id,
        country,
        cast(birth_date as date)                               as birth_date,
        cast(height_cm as float)                               as height_cm,
        cast(registered_at as timestamptz) at time zone 'UTC' as registered_at
    from source

)

select
    user_id,
    country,
    birth_date,
    height_cm,
    registered_at
from renamed
