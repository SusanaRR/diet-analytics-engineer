# dbt Conventions

Standards followed in this project. Claude reads this file when creating or editing dbt models.

---

## CTE Structure

Every model follows this order:

1. **Import CTEs** — one per dependency, no transformation. Just select the columns needed.
2. **Logic CTEs** — grouping, joining, filtering, derived columns.
3. **Final select** — selects from the last logic CTE.

```sql
with

-- 1. Import CTEs
fct_meal_log_nutrients as (

    select
        user_id,
        nutrient_id,
        logged_date,
        value_g
    from {{ ref('fct_meal_log_nutrients') }}

),

dim_users as (

    select
        user_id,
        recommended_protein_g
    from {{ ref('dim_users') }}

),

-- 2. Logic CTEs
daily_intake as (

    select
        user_id,
        nutrient_id,
        logged_date,
        sum(value_g) as daily_value_g
    from fct_meal_log_nutrients
    group by user_id, nutrient_id, logged_date

)

-- 3. Final select
select
    user_id,
    nutrient_id,
    logged_date,
    daily_value_g
from daily_intake
```

See [Whitespace](#whitespace) below for the full spacing rules (blank lines after `with`, around each CTE body, etc.).

Import CTEs are named after the model they reference (`{{ ref('x') }}` → CTE named `x`).

### Whitespace

Matches [dbt's official style guide](https://docs.getdbt.com/best-practices/how-we-style/1-how-we-style-our-dbt-models). Reference example: [stg_usda__food_nutrients.sql](../diet_dbt/models/staging/usda/stg_usda__food_nutrients.sql).

- `with` sits alone on its own line, followed by a blank line.
- Each CTE's opening `as (` is followed by a blank line, and the closing `)` is preceded by a blank line.
- A blank line separates each CTE (including before the final `select`).
- The body of a CTE is indented 4 spaces.

```sql
with

source as (

    select
        fdc_id,
        raw_json,
        loaded_at
    from {{ source('raw', 'raw_foods') }}

),

renamed as (

    select
        fdc_id,
        raw_json ->> 'description' as description
    from source

)

select
    fdc_id,
    description
from renamed
```

---

## Layer Conventions

| Layer | Materialization | Purpose |
|---|---|---|
| Staging | `view` | Clean and cast raw source data. No business logic. One-to-one with source tables. |
| Intermediate | `ephemeral` | Complex transformations: unnesting, pivoting, joining across staging models. |
| Marts | `table` | Final grain, business-ready. What reporting tools query. |

Staging models are limited to renaming, type casting, basic computation (e.g. unit conversion), and categorizing (`case when` into buckets/booleans). No joins, no aggregations — those belong in intermediate or marts. This keeps staging a 1:1, dependable building block for everything downstream.

Staging models only reference sources or seeds. Intermediate models only reference staging or other intermediates. Mart models reference intermediates or other marts — never sources directly.

Exception: a mart may reference a staging model directly when there's no real transformation to extract into an intermediate layer (pure passthrough). Same idea as marts joining seeds directly — don't add a file with no logic just to satisfy the layer count. `dim_users` reading `stg_app_events__users` directly is an example of this.

Exception: intermediate models may also join a small static seed directly (e.g. a lookup table) when it's just resolving a key, not real transformation. `int_meal_logs_unpivoted` joining the `meals` seed to resolve `meal_id` is an example of this.

---

## Naming Conventions

- **Staging**: `stg_<source>__<entity>.sql` (double underscore separates source from entity). Entity is plural — `stg_app_events__meal_logs`, not `stg_app_events__meal_log`.
- **Intermediate**: `int_<description>.sql`
- **Marts**: `dim_<entity>.sql` or `fct_<event>.sql`
- **Seeds**: `<entity>.csv` (short, lowercase, plural — `users.csv`, `meals.csv` — same reasoning as model naming below: a CSV with multiple rows reads better as a plural noun)
- **YAML files**: `_<folder>__models.yml`, `_<folder>__sources.yml`, `_seeds.yml`. Exception: intermediate-layer YAML keeps the layer prefix — `_int_<folder>__models.yml` — per [dbt's official structure guide](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate).

---

## Column Rules

- **No `SELECT *`** — always list explicit columns. Prevents hidden schema changes from breaking downstream models.
- **Explicit column list in final select** — even if it mirrors the last CTE.
- **Cast types in staging** — `cast(birth_date as date)`, `cast(weight_kg as float)`. Downstream models trust that types are already correct.
- **Derived columns go in marts** — `age`, `bmi`, `recommended_protein_g` are calculated in `dim_users`, not in staging.
- **Use date IDs in marts, not raw timestamps** — mart models expose `_date_id` columns (YYYYMMDD integer FK to `dim_date`) derived from timestamps in staging/intermediate. Raw timestamps (`_at` columns) stay in staging and are used internally in intermediate models to derive the ID, but are not passed through to marts. This keeps mart columns BI-tool friendly and avoids exposing timezone-sensitive types to reporting layers. The `date_to_id()` macro is used across models to generate these integers consistently. Note: depending on the BI tool, integer date IDs may not be necessary — Tableau, Looker, and Looker Studio all work natively with DATE types and handle date groupings automatically, making the integer ID a warehouse join key only. Exception: `fct_meal_logs`, `fct_meal_log_nutrients`, and `fct_user_segments` also expose the plain `logged_date` column alongside `logged_date_id`, as a simplification for the Streamlit dashboard — decoding a YYYYMMDD integer in every query adds complexity for no benefit at this scale.

---

## Column Naming

Per [dbt's official style guide](https://docs.getdbt.com/best-practices/how-we-style/1-how-we-style-our-dbt-models):

- **Primary keys**: `<entity>_id` (`user_id`, `fdc_id`, `nutrient_id`) — makes it obvious what's being referenced in a downstream join, instead of a bare `id`.
- **Booleans**: prefix with `is_` or `has_` (`is_flagged`).
- **Timestamps**: `<event>_at`, in UTC (`loaded_at`, `created_at`).
- **Dates**: `<event>_date` (`logged_date`, `birth_date`).
- **Column order in a select**: ids, strings, numerics, booleans, dates, timestamps — in that order. Minimizes join errors and makes columns easy to scan for.

---

## Seeds

Use seeds for small, static reference data that rarely changes and is small enough to version-control as CSV:
- Lookup tables (meals, nutrients, bmi_categories)
- Generic thresholds (nutrient_daily_targets)
- Demo/synthetic data (users)

Seeds are referenced with `{{ ref('seed_name') }}` exactly like models. No staging model needed on top of a seed — marts can join seeds directly.

**When to wrap a seed in a `dim_` mart:** if the seed produces a FK column that appears in a fact table (e.g. `meal_id` in `fct_meal_logs`), wrap it in a `dim_` mart so the BI layer has a proper dimension to join against. If the seed is only ever joined inside intermediate models for classification purposes and its output flows into a column value rather than a FK (e.g. `bmi_categories` → `bmi_category` string in `dim_users`, `nutrient_daily_targets` → `threshold_g` in `fct_user_segments_windowed`), leave it as a plain seed with no wrapper.

---

## SQL Style

- **`UNION ALL` not `UNION`** — unless deduplication is explicitly needed. `UNION ALL` is more performant: `UNION` adds a sort/dedup step (hash + deduplication pass) that is wasted if rows are inherently distinct. `UNION ALL` skips that step entirely and just appends result sets.
- **`{% set %}` without leading trim dash** — use `{% set ... %}` not `{%- set ... %}`. Leading trim dashes can cause SQL comments to swallow subsequent keywords at compile time.
- **`INNER JOIN` over `JOIN`** — be explicit about join type.
- **`coalesce()` for null handling** — apply in the `renamed` CTE of staging models where possible. Intermediate models are also acceptable when nulls arise from the transformation itself (e.g. unnesting, pivoting, or joining nested structures) rather than from the raw source.
- **No alias abbreviations in joins** — use the full CTE name as the alias, not a single letter or abbreviation. `unpivoted.user_id` not `u.user_id`. Abbreviations obscure where a column comes from and make queries harder to review. Per [dbt's official style guide](https://docs.getdbt.com/best-practices/how-we-style/1-how-we-style-our-dbt-models#sql-style-guide).
- **Prefer window functions over self-joins or correlated subqueries** when the operation is row-level and performance matters. Common cases:
  - Deduplication → `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` instead of a self-join.
  - Running totals → `SUM(value_g) OVER (PARTITION BY user_id ORDER BY logged_date)` instead of a correlated subquery.
  - Period-over-period comparisons → `LAG(value_g) OVER (...)` / `LEAD(value_g) OVER (...)` instead of joining the same table twice.
  - First/last value per group → `FIRST_VALUE(...) OVER (...)` instead of a subquery with `MIN`/`MAX` and a re-join.
  Window functions scan the partition once; self-joins and correlated subqueries re-scan the table for every row.

---

## Testing

- `unique` and `not_null` on all primary keys and foreign keys.
- `accepted_values` for columns with a fixed set of valid values (e.g. `threshold_type`, `meal_name`).
- `dbt_utils.accepted_range` for numeric columns with known bounds (e.g. nutrient values 0–100).
- Tests live in the model YAML file alongside column descriptions.

### dbt docs

Column descriptions and data tests in YAML files feed directly into `dbt docs generate`, which produces a browsable data catalog with lineage graphs. Keeping descriptions accurate and complete is what makes the generated docs useful — treat them as part of the model, not optional metadata.

---

## Model YAML Defaults

Every model entry in a `models:` YAML file includes, at minimum:

- `name` — the model name.
- `description` — what one row represents (e.g. "One row per SR Legacy Food..."). Use the `>` block style for anything longer than a single line.
- `columns`, one entry per column, each with:
  - `name`
  - `data_type`
  - `description` — short, quoted string.
  - `data_tests` — at minimum `unique` and `not_null` on primary keys (see [Testing](#testing)); omit `data_tests` entirely on columns with no applicable test rather than leaving an empty list.

Reference example: [_usda__models.yml](../diet_dbt/models/staging/usda/_usda__models.yml).

```yaml
version: 2

models:
  - name: stg_usda__food_nutrients
    description: >
      One row per SR Legacy Food, with scalar fields extracted from the raw
      JSON.
    columns:
      - name: fdc_id
        data_type: integer
        description: "Unique identifier for the food"
        data_tests:
          - unique
          - not_null
      - name: publication_date
        data_type: date
        description: "Date this food record was published to FoodData Central"
```

---

## Snapshot Columns

dbt automatically adds the following columns to snapshot tables:

| Column | Type | Description |
|---|---|---|
| `dbt_scd_id` | `varchar` | Surrogate key — hash of `unique_key` + `dbt_valid_from` |
| `dbt_valid_from` | `timestamptz` | When this version became current |
| `dbt_valid_to` | `timestamptz` | When this version was superseded; `null` if still current |
| `dbt_updated_at` | `timestamptz` | When dbt last evaluated this row |

`timestamptz` means "timestamp with time zone" — dbt writes these in UTC by default. No explicit UTC conversion is needed for snapshot columns, unlike raw `_at` timestamps from source systems which must be normalised in staging.

---

## Audit Columns

Traditional operational DB audit columns (`created_at`, `updated_at`, `created_by`, `updated_by`) do not apply to dbt models. dbt rebuilds models from source data on every run — there is no concept of a row being independently created or updated by a user or process. Auditability lives at the pipeline level instead:

- **`loaded_at`** on raw tables — tracks when the extraction script loaded the row. Already in place on `raw_foods`. This is the raw-layer equivalent of `created_at`.
- **Snapshot columns** — dbt adds `dbt_valid_from`, `dbt_valid_to`, and `dbt_updated_at` automatically on snapshot tables (e.g. `dim_foods_snapshot`). These are the only row-level audit columns in the warehouse.
- **dbt run results** — timing, status, and model metadata are captured in dbt's run logs, not in table columns.
- **Source event timestamps** (`registered_at`, `logged_at`) — more meaningful than pipeline timestamps because they reflect when something happened in the app, not when the pipeline ran.

Do not add `created_by` or `updated_by` columns — the "author" is always the pipeline, and that is captured in git history and Airflow run logs, not in table rows.

---

## Jinja / dbt Templating

- Always use `{{ ref('model_name') }}` to reference models and seeds — never hardcode schema or table names.
- Always use `{{ source('source_name', 'table_name') }}` for raw source tables.
- Database name in sources YAML: `"{{ env_var('TARGET_ENV', 'dev') }}_diet_app"` — dbt does not read `.env` files, so `TARGET_ENV` must be exported to the shell or set as an Airflow Variable in production.

---

## Tags

Tags are set in the model YAML under `config.tags` and used to control which models run in a given `dbt build` call.

### `static` tag

Apply to models that represent fixed reference data that never changes between pipeline runs and does not need to be rebuilt daily. The only current example is `dim_date` — a pre-generated date spine covering 2019–2027.

```yaml
- name: dim_date
  config:
    tags: ['static']
```

Exclude static models from daily builds:

```bash
dbt build --exclude tag:static
```

Run static models manually only when their content needs to change (e.g. extending the date range in `dim_date`):

```bash
dbt run --select dim_date
```

This tag is also how the Airflow DAG will distinguish daily-refresh models from one-off setup models — the daily operator will always pass `--exclude tag:static`.

When creating a new model YAML entry, check whether the model produces static reference data before omitting the tag. Good candidates: pre-generated date/calendar tables, static lookup dimensions populated from a fixed CSV-like query. Bad candidates: any model that joins to `raw_meal_logs` or any other source that updates daily.

---

## Schema Separation

Configured in `dbt_project.yml` via `+schema`. Produces `<target>_<schema>` in DuckDB:

```yaml
staging:  +schema: staging   → dev_staging
marts:    +schema: marts     → dev_marts
marketing: +schema: marketing → dev_marketing
```

Do not use the `generate_schema_name` macro — use `+schema` in `dbt_project.yml` instead for simplicity.
