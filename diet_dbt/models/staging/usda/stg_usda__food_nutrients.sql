-- Null handling strategy:
-- description: coalesce to 'Unknown' — a missing name is recoverable and should not block the pipeline.
-- publication_date, raw_json, loaded_at: no coalesce — nulls here indicate an extraction failure
--   and should be caught by not_null tests rather than silently passed downstream.

with

source as (

    select
        fdc_id,
        raw_json,
        loaded_at
    from {{ source('raw', 'raw_foods') }}

),

initial_column_extraction as (

    select
        fdc_id,
        coalesce(raw_json ->> 'description', 'Unknown') as description,
        cast(raw_json ->> 'publicationDate' as date) as publication_date,
        raw_json,
        loaded_at at time zone 'UTC' as loaded_at
    from source

)

select
    fdc_id,
    description,
    publication_date,
    raw_json,
    loaded_at
from initial_column_extraction
