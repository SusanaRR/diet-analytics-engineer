# SQL Conventions — Python Scripts

Standards for SQL written in the extraction and setup scripts (`usda/`, `app_events/`, `setup/`). For dbt model SQL, see [dbt_conventions.md](dbt_conventions.md).

---

## File location

SQL for Python scripts lives in a `queries/` folder next to the script — never inlined as Python strings.

```
usda/
├── usda_extract.py
└── queries/
    ├── 01_create_raw_foods.sql
    └── 02_insert_raw_foods.sql

app_events/
├── generate_historical_meal_logs.py
└── queries/
    ├── 01_get_fdc_ids.sql
    ├── 02_truncate_meal_logs.sql
    └── 03_insert_meal_logs.sql
```

Files are numbered by execution order (`01_`, `02_`, `03_`) so the intended sequence is visible without reading the Python.

---

## Loading SQL in Python

```python
def load_sql(filename):
    return open(os.path.join(queries_dir, filename)).read().format(database=db_name)
```

Always load via `open(path).read()` — never inline SQL as a Python string. This keeps SQL readable, lintable, and editable without touching Python files.

---

## Database placeholder

All SQL files use `{database}` as the database name placeholder. Python passes the full name at load time via `.format(database=db_name)`:

```sql
-- queries/01_create_raw_foods.sql
CREATE TABLE IF NOT EXISTS {database}.raw.raw_foods (
    fdc_id    INTEGER,
    raw_json  JSON,
    loaded_at TIMESTAMPTZ DEFAULT now()
);
```

```python
db_name = f"{env_prefix}_diet_app"   # e.g. "dev_diet_app"
conn.execute(load_sql("01_create_raw_foods.sql"))
```

Never hardcode the database name in a SQL file.

---

## No SELECT *

All queries use explicit column lists. Prevents hidden schema changes from silently breaking downstream consumers.

```sql
-- ✅
SELECT fdc_id, raw_json, loaded_at FROM {database}.raw.raw_foods;

-- ❌
SELECT * FROM {database}.raw.raw_foods;
```

---

## Batched inserts

Use DuckDB's `INSERT INTO ... SELECT ... FROM df` pattern with a registered DataFrame — not row-by-row inserts and not `executemany` with Python loops. DuckDB can query a pandas DataFrame directly:

```python
# Generate df in Python, then let DuckDB do the insert in one shot
conn.execute("INSERT INTO {database}.app_events.raw_meal_logs SELECT * FROM df")
```

This is faster than any loop-based approach and keeps the insert logic in SQL where it belongs.

---

## Raw layer rule

Raw tables store API responses as-is — no parsing, no typing, no transformation at insert time. The raw JSON column is stored exactly as received from the API:

```sql
INSERT INTO {database}.raw.raw_foods (fdc_id, raw_json, loaded_at)
SELECT $1, $2, now()
```

All parsing and typing happens in dbt staging models, not in the extraction scripts. This preserves the original response and makes re-processing possible without re-hitting the API.

---

## Table creation

Use `CREATE TABLE IF NOT EXISTS` for idempotency — scripts must be safe to re-run without manual cleanup:

```sql
CREATE TABLE IF NOT EXISTS {database}.raw.raw_foods (
    fdc_id    INTEGER,
    raw_json  JSON,
    loaded_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Truncate before re-insert

Daily scripts truncate before inserting, not upsert or merge. Keeps the logic simple and the script idempotent — safe to re-run on the same day without producing duplicates. Historical data is not at risk because it lives in the incremental mart tables, not in the raw table.

```sql
-- 02_truncate_meal_logs.sql
TRUNCATE {database}.app_events.raw_meal_logs;

-- 03_insert_meal_logs.sql
INSERT INTO {database}.app_events.raw_meal_logs (user_id, breakfast, lunch, dinner, logged_at)
SELECT user_id, breakfast, lunch, dinner, logged_at FROM df;
```

---

## General SQL style

These apply everywhere — both Python script SQL and dbt model SQL:

- **`INNER JOIN` not `JOIN`** — be explicit about join type.
- **`UNION ALL` not `UNION`** — unless deduplication is explicitly needed.
- **No alias abbreviations** — use the full table or CTE name, not single letters (`u`, `f`, `m`).
- **Lowercase keywords** — `select`, `from`, `where`, `inner join` (consistent with dbt style).
- **No trailing whitespace** — keep files clean for git diffs.
