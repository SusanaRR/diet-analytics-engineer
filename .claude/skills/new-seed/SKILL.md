# new-seed

Add a new dbt seed to the project following conventions in CLAUDE.md and docs/dbt_conventions.md.

## Trigger

Use when the user asks to create or add a new dbt seed.

## Steps

Before writing anything, ask the user for:
- Columns and their data types
- Purpose (lookup/helper vs business logic vs user data)
- Whether a staging model is needed on top of it

Then:

**1. Create the CSV file:**
- `diet_dbt/seeds/<name>.csv` with a header row and representative rows

**2. Add an entry to `diet_dbt/seeds/_seeds.yml` with:**
- `description` explaining the purpose and how it is used downstream
- All columns with `description` and `data_tests`
- `unique` + `not_null` on the primary key column
- `accepted_values` or `dbt_utils.accepted_range` where appropriate

**3. If a staging model is needed:**
- Create `diet_dbt/models/staging/app_events/stg_app_events__<name>.sql`
- Add the entry to `diet_dbt/models/staging/app_events/_app_events__models.yml`
- Cast types in the `renamed` CTE; normalise any timestamps to UTC using `AT TIME ZONE 'UTC'`
- Derive `_date_id` columns using `{{ date_to_id(...) }}` macro

Propose the files and wait for confirmation before writing anything.
