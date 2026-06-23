-- Date dimension generated from a date spine (2019-01-01 to 2027-12-31).
-- date_id is a YYYYMMDD integer surrogate key — fact tables reference this
-- instead of a raw date, enabling easy filtering by year/month/day in BI tools
-- without extracting from a date column every time.
-- Generated once as a table; re-run when the range needs extending.
--
-- Start date is 2019-01-01 to cover USDA publication_date values (earliest
-- observed: 2019-04-01), which predate the app launch. Without this, FK joins
-- from dim_foods to dim_date on publication_date_id would produce no matches.

with

date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2019-01-01' as date)",
        end_date="cast('2027-12-31' as date)"
    ) }}

),

date_attributes as (

    select
        {{ date_to_id('date_day') }}        as date_id,
        date_day                            as full_date,
        cast(year(date_day) as integer)     as year,
        cast(quarter(date_day) as integer)  as quarter,
        cast(month(date_day) as integer)    as month,
        monthname(date_day)                 as month_name,
        cast(week(date_day) as integer)     as week_of_year,
        cast(day(date_day) as integer)      as day_of_month,
        cast(dayofweek(date_day) as integer) as day_of_week,
        dayname(date_day)                   as day_name,
        dayofweek(date_day) in (0, 6)       as is_weekend
    from date_spine

)

select
    date_id,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
from date_attributes
