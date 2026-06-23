# Dimensional Model

Dimensional design follows Kimball's methodology. This document covers the bus matrix, grain statements, role-playing dimensions, SCD types, fact table types, and the SQL queries used for reporting.

---

## Bus Matrix

Maps each fact table to the dimensions it shares. A ✓ indicates the fact table joins to that dimension. Dimensions appearing in more than one row are conformed — shared across fact tables with a single definition.

|  | dim_date | dim_users | dim_foods | dim_meals | dim_nutrients |
|---|---|---|---|---|---|
| `fct_meal_logs` | ✓ | ✓ | ✓ | ✓ | |
| `fct_meal_log_nutrients` | ✓ | ✓ | | ✓ | ✓ |
| `fct_bmi_evolution` | ✓ | ✓ | | | |
| `fct_user_segments` | ✓ | ✓ | | | ✓ |
| `fct_user_segments_windowed` | | ✓ | | | ✓ |

---

## Grain Statements

Each fact table has a declared grain — the finest level of detail the table represents. Rows must be unique at this grain.

| Table | Grain |
|---|---|
| `fct_meal_logs` | One row per user × meal × food item × day |
| `fct_meal_log_nutrients` | One row per user × meal × nutrient × day |
| `fct_bmi_evolution` | One row per weight log entry per user |
| `fct_user_segments` | One row per user × nutrient × day |
| `fct_user_segments_windowed` | One row per user × nutrient (latest snapshot) |

---

## Role-Playing Dimensions

`dim_date` plays multiple roles across the model — the same physical table is joined under different foreign key aliases depending on context. This is the standard Kimball pattern for date dimensions.

> **BI tool note:** modern tools like Tableau, Looker, and Looker Studio handle date grouping (by month, week, year) natively on a plain `DATE` column, making the integer date ID and the `dim_date` join optional for basic reporting. The role-playing pattern becomes relevant when you need calendar attributes (e.g. `is_weekend`, `month_name`) that the BI tool cannot derive on its own, or when joining across multiple date roles in the same query.

| Fact table | Role | Foreign key |
|---|---|---|
| `fct_meal_logs` | Day meals were logged | `logged_date_id` |
| `fct_meal_log_nutrients` | Day nutrients were consumed | `logged_date_id` |
| `fct_bmi_evolution` | Day weight was recorded | `recorded_date_id` |
| `fct_user_segments` | Day segment was classified | `logged_date_id` |
| `dim_users` | Day user registered | `registered_date_id` |
| `dim_foods` | Day food data was loaded | `loaded_date_id` |
| `dim_foods` | USDA publication date | `publication_date_id` |

---

## Fact Table Types

Kimball defines three fact table types. This project uses two of them.

| Type | Description | Tables in this project |
|---|---|---|
| **Transaction fact** | One row per discrete event at the finest grain | `fct_meal_logs`, `fct_meal_log_nutrients`, `fct_bmi_evolution`, `fct_user_segments` |
| **Periodic snapshot** | One row per user per period, capturing state at a point in time | `fct_user_segments_windowed` (snapshot of last day / 7d / 30d) |
| **Accumulating snapshot** | One row per process instance, updated as it progresses | Not used — no multi-step processes in this domain |

---

## Slowly Changing Dimensions

| Dimension | SCD Type | Implementation |
|---|---|---|
| `dim_foods` | Type 2 | `dim_foods_snapshot` — new row on any nutrient value change; `dbt_scd_id` is the surrogate key |
| `dim_users` | Type 1 | Overwrite in place — current BMI and weight only; history tracked separately in `fct_bmi_evolution` |

---

## Segment Definitions

`fct_user_segments` classifies each user per day against four behavioural segments. Carbohydrate is tracked as a nutrient but is not targeted in this iteration.

| Segment | Nutrient | Direction | Threshold |
|---|---|---|---|
| `low_protein` | Protein | Below | `weight_kg × 0.8g` (personalised per user) |
| `high_fat` | Fat | Above | 78g (FDA) |
| `low_fiber` | Fiber | Below | 28g (FDA) |
| `high_sugar` | Total sugar | Above | 50g (WHO) |

Thresholds are stored in the `nutrient_daily_targets` seed so they can be updated without changing model code.

---

## Reporting Queries

SQL queries against the mart layer for dashboard and ad-hoc reporting.
All queries use full table/column names — no alias abbreviations.

> **BI tool note:** table names reference the target schema configured in the tool connection.
> Date literals shown as examples should be replaced with BI tool parameters before publication.

### Available tables

| Table | Grain | Purpose |
|---|---|---|
| `fct_meal_log_nutrients` | user × meal × nutrient × day | Nutrient intake per meal — foundation for all intake reports |
| `fct_user_segments` | user × nutrient × day | Daily classification against recommended thresholds |
| `fct_user_segments_windowed` | user × nutrient | Windowed snapshot: last day / 7d / 30d |
| `fct_meal_logs` | user × meal × food item × day | Food items per meal with serving size |
| `fct_bmi_evolution` | weight log entry | BMI history per user |
| `dim_users` | user | User profile, BMI, recommended protein |
| `dim_foods` | fdc_id | Food descriptions and nutrient content per 100g |
| `dim_nutrients` | nutrient_id | Nutrient names and USDA codes |
| `dim_date` | date | Date spine 2019-01-01 to 2027-12-31 with calendar attributes |

---

### Report 1 — Daily Nutrient Intake

Total grams consumed per nutrient per user per day, summed across all meals.
Suitable for a bar or line chart with date and user filters.

**Tables:** `fct_meal_log_nutrients`, `dim_nutrients`

```sql
select
    fct_meal_log_nutrients.user_id,
    dim_nutrients.nutrient_name,
    fct_meal_log_nutrients.logged_date,
    sum(fct_meal_log_nutrients.value_g)      as daily_value_g
from fct_meal_log_nutrients
inner join dim_nutrients
    on fct_meal_log_nutrients.nutrient_id = dim_nutrients.nutrient_id
group by
    fct_meal_log_nutrients.user_id,
    dim_nutrients.nutrient_name,
    fct_meal_log_nutrients.logged_date
order by
    fct_meal_log_nutrients.logged_date,
    fct_meal_log_nutrients.user_id,
    dim_nutrients.nutrient_name
```

---

### Report 2 — Weekly Average Intake

Per-week average intake per user per nutrient.
`week_start` is the Monday of each ISO week.

**Tables:** `fct_meal_log_nutrients`, `dim_nutrients`

```sql
with daily as (
    select
        user_id,
        nutrient_id,
        logged_date,
        sum(value_g)                         as daily_value_g
    from fct_meal_log_nutrients
    group by user_id, nutrient_id, logged_date
)
select
    daily.user_id,
    dim_nutrients.nutrient_name,
    date_trunc('week', daily.logged_date)    as week_start,
    round(avg(daily.daily_value_g), 2)       as weekly_avg_g
from daily
inner join dim_nutrients
    on daily.nutrient_id = dim_nutrients.nutrient_id
group by
    daily.user_id,
    daily.nutrient_id,
    dim_nutrients.nutrient_name,
    week_start
order by week_start, daily.user_id, dim_nutrients.nutrient_name
```

---

### Report 3 — Monthly Average and Month-over-Month

Per-month average intake and delta versus the prior month via `LAG`.
A positive `mom_delta_g` means intake increased versus the previous month.

**Tables:** `fct_meal_log_nutrients`, `dim_nutrients`

```sql
with daily as (
    select
        user_id,
        nutrient_id,
        logged_date,
        sum(value_g)                             as daily_value_g
    from fct_meal_log_nutrients
    group by user_id, nutrient_id, logged_date
),
monthly as (
    select
        daily.user_id,
        daily.nutrient_id,
        dim_nutrients.nutrient_name,
        date_trunc('month', daily.logged_date)   as month_start,
        round(avg(daily.daily_value_g), 2)       as monthly_avg_g
    from daily
    inner join dim_nutrients
        on daily.nutrient_id = dim_nutrients.nutrient_id
    group by
        daily.user_id,
        daily.nutrient_id,
        dim_nutrients.nutrient_name,
        month_start
)
select
    user_id,
    nutrient_name,
    month_start,
    monthly_avg_g,
    lag(monthly_avg_g) over (
        partition by user_id, nutrient_id
        order by month_start
    )                                            as prev_month_avg_g,
    round(
        monthly_avg_g
        - lag(monthly_avg_g) over (
            partition by user_id, nutrient_id
            order by month_start
          ),
        2
    )                                            as mom_delta_g
from monthly
order by user_id, nutrient_name, month_start
```

---

### Report 4 — Day-by-Day Evolution with 7-Day Rolling Average

Daily intake alongside a 7-day rolling average per user per nutrient.
Suitable for a line chart where the rolling average smooths single-day spikes.
`week_of_year` and `month_name` are included for BI tool grouping.

**Tables:** `fct_meal_log_nutrients`, `dim_nutrients`, `dim_date`

```sql
with daily as (
    select
        fct_meal_log_nutrients.user_id,
        fct_meal_log_nutrients.nutrient_id,
        dim_nutrients.nutrient_name,
        fct_meal_log_nutrients.logged_date,
        dim_date.week_of_year,
        dim_date.month_name,
        sum(fct_meal_log_nutrients.value_g)                              as daily_value_g
    from fct_meal_log_nutrients
    inner join dim_nutrients
        on fct_meal_log_nutrients.nutrient_id = dim_nutrients.nutrient_id
    inner join dim_date
        on fct_meal_log_nutrients.logged_date_id = dim_date.date_id
    group by
        fct_meal_log_nutrients.user_id,
        fct_meal_log_nutrients.nutrient_id,
        dim_nutrients.nutrient_name,
        fct_meal_log_nutrients.logged_date,
        dim_date.week_of_year,
        dim_date.month_name
)
select
    user_id,
    nutrient_name,
    logged_date,
    week_of_year,
    month_name,
    daily_value_g,
    round(avg(daily_value_g) over (
        partition by user_id, nutrient_id
        order by logged_date
        rows between 6 preceding and current row
    ), 2)                                                                as rolling_7d_avg_g
from daily
order by user_id, nutrient_name, logged_date
```

---

### Report 5 — Current Segmentation (Latest Day)

Each user's segment status for the most recent logged date.
`is_flagged = true` means the user is outside the recommended range for that nutrient.
Segment labels: `low_protein`, `high_fat`, `low_fiber`, `high_sugar`.

**Tables:** `fct_user_segments`, `dim_nutrients`

```sql
select
    fct_user_segments.user_id,
    dim_nutrients.nutrient_name,
    fct_user_segments.logged_date,
    fct_user_segments.daily_value_g,
    fct_user_segments.threshold_g,
    fct_user_segments.threshold_type,
    fct_user_segments.segment_label,
    fct_user_segments.is_flagged
from fct_user_segments
inner join dim_nutrients
    on fct_user_segments.nutrient_id = dim_nutrients.nutrient_id
where fct_user_segments.logged_date = (
    select max(logged_date) from fct_user_segments
)
order by fct_user_segments.user_id, dim_nutrients.nutrient_name
```

---

### Report 6 — Windowed Segmentation (Last Day / 7d / 30d)

Intake averages over three windows per user per nutrient: last single day, last 7 days,
last 30 days. Pre-computed in `fct_user_segments_windowed`.

**Tables:** `fct_user_segments_windowed`, `dim_nutrients`

```sql
select
    fct_user_segments_windowed.user_id,
    dim_nutrients.nutrient_name,
    fct_user_segments_windowed.segment_label,
    fct_user_segments_windowed.threshold_g,
    fct_user_segments_windowed.threshold_type,
    fct_user_segments_windowed.last_day_g,
    fct_user_segments_windowed.last_7d_avg_g,
    fct_user_segments_windowed.last_30d_avg_g,
    fct_user_segments_windowed.is_flagged_last_day,
    fct_user_segments_windowed.is_flagged_last_7d,
    fct_user_segments_windowed.is_flagged_last_30d
from fct_user_segments_windowed
inner join dim_nutrients
    on fct_user_segments_windowed.nutrient_id = dim_nutrients.nutrient_id
order by fct_user_segments_windowed.user_id, dim_nutrients.nutrient_name
```

---

### Report 7 — Segment Pivot Table

One row per user, one boolean column per segment, based on the latest logged day.
Designed for a matrix-style filter table where analysts can select one or many segments.

**Tables:** `fct_user_segments`

```sql
select
    fct_user_segments.user_id,
    max(case
        when fct_user_segments.segment_label = 'low_protein'
         and fct_user_segments.is_flagged
        then true else false
    end)                           as low_protein,
    max(case
        when fct_user_segments.segment_label = 'high_fat'
         and fct_user_segments.is_flagged
        then true else false
    end)                           as high_fat,
    max(case
        when fct_user_segments.segment_label = 'low_fiber'
         and fct_user_segments.is_flagged
        then true else false
    end)                           as low_fiber,
    max(case
        when fct_user_segments.segment_label = 'high_sugar'
         and fct_user_segments.is_flagged
        then true else false
    end)                           as high_sugar
from fct_user_segments
where fct_user_segments.logged_date = (
    select max(logged_date) from fct_user_segments
)
group by fct_user_segments.user_id
order by fct_user_segments.user_id
```

---

### Report 8 — Daily Food Log

All food items logged per user on a specific day, broken down by meal.
Replace the hardcoded date with a BI tool date parameter.

**Tables:** `fct_meal_logs`, `dim_foods`, `dim_meals`

```sql
select
    fct_meal_logs.user_id,
    fct_meal_logs.logged_date,
    dim_meals.meal_name,
    dim_foods.description                  as food_name,
    fct_meal_logs.grams
from fct_meal_logs
inner join dim_foods
    on fct_meal_logs.fdc_id = dim_foods.fdc_id
inner join dim_meals
    on fct_meal_logs.meal_id = dim_meals.meal_id
where fct_meal_logs.logged_date = '2026-06-21'   -- replace with target date
order by
    fct_meal_logs.user_id,
    dim_meals.meal_name,
    dim_foods.description
```

---

### Report 9 — Weekly Food Log

Food consumption at week grain: how many times each food appeared and the average serving size.
Useful for a "most eaten foods this week" table.

**Tables:** `fct_meal_logs`, `dim_foods`, `dim_meals`

```sql
select
    fct_meal_logs.user_id,
    date_trunc('week', fct_meal_logs.logged_date) as week_start,
    dim_meals.meal_name,
    dim_foods.description                          as food_name,
    count(*)                                       as times_logged,
    round(avg(fct_meal_logs.grams), 1)             as avg_grams
from fct_meal_logs
inner join dim_foods
    on fct_meal_logs.fdc_id = dim_foods.fdc_id
inner join dim_meals
    on fct_meal_logs.meal_id = dim_meals.meal_id
group by
    fct_meal_logs.user_id,
    week_start,
    dim_meals.meal_name,
    dim_foods.description
order by
    fct_meal_logs.user_id,
    week_start,
    dim_meals.meal_name,
    times_logged desc
```

---

### Report 10 — BMI Evolution Over Time

BMI at each point where a user's weight was updated.
Each row is a weight log entry; suitable for a per-user line chart.

**Tables:** `fct_bmi_evolution`, `dim_date`

```sql
select
    fct_bmi_evolution.user_id,
    dim_date.full_date                        as recorded_date,
    fct_bmi_evolution.weight_kg,
    fct_bmi_evolution.height_cm,
    fct_bmi_evolution.bmi
from fct_bmi_evolution
inner join dim_date
    on fct_bmi_evolution.recorded_date_id = dim_date.date_id
order by fct_bmi_evolution.user_id, dim_date.full_date
```

---

## Mart decisions

The following aggregations were considered as separate mart models and deliberately left to the BI tool instead:

| Considered model | Decision | Reason |
|---|---|---|
| `fct_daily_nutrient_intake` | Not built | `int_daily_nutrient_intake` already exists as intermediate; BI tool sums from `fct_meal_log_nutrients` |
| Weekly rollup mart | Not built | BI tool `date_trunc('week', ...)` + `avg()` is sufficient |
| Monthly rollup mart | Not built | Same reason as weekly |
| MoM delta mart | Not built | `LAG` belongs in the BI tool or a metric definition; not complex enough to pre-compute |
| Daily flagged user counts | Not built | Simple aggregation of `fct_user_segments` — computed in the dashboard query directly |

Models pre-computed because the logic is too complex for the BI tool:

| Model | Reason |
|---|---|
| `fct_user_segments_windowed` | Rolling window classification across 3 time cuts |
| `fct_bmi_evolution` | Requires joining weight logs to users with a range join for BMI category |
