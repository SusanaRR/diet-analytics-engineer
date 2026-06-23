# dbt Commands

Quick reference for commands used while working on this project.

---

## Build

| Command | What it does |
|---|---|
| `dbt run` | Builds models (runs the `SELECT`/`CREATE` against the warehouse). |
| `dbt build` | Runs models, tests, seeds, and snapshots together, respecting dependency order. |
| `dbt seed` | Loads CSV files from `seeds/` into the warehouse as tables. |
| `dbt test` | Runs the `data_tests` defined in model/seed YAML files. |

## Freshness and snapshots

| Command | What it does |
|---|---|
| `dbt source freshness` | Checks whether source tables have been updated within the configured warn/error thresholds. Run before `dbt build` to confirm source data is current. |
| `dbt snapshot` | Runs snapshot models only. Adds new SCD Type 2 rows where tracked columns have changed since the last run. Also triggered by `dbt build` — use this command when running snapshots independently (e.g. on a different schedule). |

---

## Inspect / validate

| Command | What it does |
|---|---|
| `dbt parse` | Validates Jinja/YAML syntax across the project. No SQL is run against the warehouse — catches templating and config errors fast. |
| `dbt compile` | Renders Jinja into raw SQL without executing it. Useful for checking what a model actually resolves to (e.g. macro loops, `ref`/`source` resolution). |
| `dbt show --select <model>` | Compiles and runs a model's SQL, previewing the result rows without materializing it. |
| `dbt list` | Lists resources (models, tests, sources, etc.) matching a selection, without running anything. |

## Selection

Commands like `run`, `build`, and `test` accept `--select`:

- `--select my_model` — just that model.
- `--select my_model+` — that model and everything downstream.
- `--select +my_model` — that model and everything upstream.
- `--select path:models/staging` — everything under a path.
- `--select source:app_events.raw_meal_logs+` — a source table and all downstream models. Useful for the daily run where only `raw_meal_logs` changes.

## Docs

| Command | What it does |
|---|---|
| `dbt docs generate` | Builds the static documentation site (model graph, descriptions, columns). |
| `dbt docs serve` | Serves the generated docs site locally. |
