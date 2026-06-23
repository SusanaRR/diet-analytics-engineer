# diet-analytics-engineer

A 3-day portfolio project showcasing dbt with DuckDB. Choices favour clarity for a dbt audience over production hardening.

## Stack

DuckDB → dbt-core + dbt-duckdb → Streamlit. Airflow is the planned next iteration.

## Data flow

1. `usda/usda_extract.py` — pulls USDA FoodData Central API → `raw.raw_foods` (raw JSON, no parsing)
2. `app_events/generate_historical_meal_logs.py` — generates synthetic meal logs → `app_events.raw_meal_logs`
3. `app_events/generate_meal_logs.py` — daily script, truncates then inserts today's logs
4. `dbt build` — staging → intermediate → marts → Streamlit dashboard

## Nutrients tracked

| Code | Column |
|------|--------|
| 203  | protein_g |
| 204  | fat_g |
| 205  | carbohydrate_g |
| 291  | fiber_g |
| 269  | total_sugar_g |

Do not widen to other nutrients without reason. Carbohydrate is tracked but not targeted in segmentation.

## Marketing segments

`low_protein`, `high_fat`, `low_fiber`, `high_sugar` — driven by `nutrient_daily_targets` seed. Protein threshold is personalised (`weight_kg × 0.8`); all others are fixed FDA/WHO values.

## Data windows

- Nutrient intake intermediate models: last 365 days
- Windowed segmentation (`int_user_segments_windowed`): last 30 days

## Standards

- dbt conventions: [`docs/dbt_conventions.md`](docs/dbt_conventions.md) — read before creating or editing any model, seed, or YAML
- SQL conventions: [`docs/sql_conventions.md`](docs/sql_conventions.md) — covers Python script SQL patterns
- Raw layer: store API responses as-is; all parsing in staging
- SQL for Python scripts goes in a `queries/` folder next to the script, never inlined
- Batched inserts (DuckDB DataFrame insert) — no row-by-row
