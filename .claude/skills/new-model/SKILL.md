# new-model

Create a new dbt model following project conventions in CLAUDE.md and docs/dbt_conventions.md.

## Trigger

Use when the user asks to scaffold, create, or add a new dbt model.

## Steps

Before writing anything, ask the user for:
- Source table(s) or upstream model(s)
- Grain (what one row represents)
- Key columns and their data types
- Purpose / what question this model answers

Then:

**1. Infer the layer from the name prefix:**
- `stg_` → staging, folder `models/staging/`, materialization: view
- `int_` → intermediate, folder `models/intermediate/`, materialization: ephemeral
- `dim_` or `fct_` → mart, folder `models/marts/core/`, `models/marts/user_health/`, or `models/marts/marketing/`, materialization: table

**2. Create the SQL file with:**
- Header comment stating grain, source models, and purpose
- One CTE per source model at the top, named after the model (no alias abbreviations in joins)
- Logic CTEs in the middle
- Single final `select` at the bottom with no inline subqueries and no joins
- `{{ date_to_id('col') }}` macro for any YYYYMMDD integer date FK columns
- Raw timestamps (`_at`) in staging/intermediate only — marts expose `_date_id` columns only

**3. Add an entry to the layer's `_models.yml` with:**
- `description` including the grain statement
- All columns with `data_type`, `description`, and `data_tests`
- `not_null` on all key columns
- `relationships` test on all FK columns pointing to their dimension
- `unique` on the primary key

Propose the files and wait for confirmation before writing anything.
