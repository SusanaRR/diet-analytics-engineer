# check-model

Review a dbt model against project conventions in CLAUDE.md and docs/dbt_conventions.md.

## Trigger

Use when the user asks to review, check, or audit a dbt model.

## How to validate

Use the dbt MCP to consult dbt best practices and verify conventions. Do not run compile, test, or any other dbt commands via MCP or bash — the user prefers to run those manually.

## Steps

Read the SQL file and its YAML entry, then check:

**Structure**
- [ ] Header comment states grain, source models, and purpose
- [ ] One CTE per source at the top, named after the source model
- [ ] No inline subqueries — all logic in named CTEs
- [ ] Single final `select` with no transformation logic and no joins

**Naming and columns**
- [ ] No alias abbreviations in joins — full CTE names used throughout
- [ ] Column names follow conventions (`_id` suffix for FKs, `_at` for timestamps, `_date_id` for YYYYMMDD integers)
- [ ] No `SELECT *` anywhere — all columns listed explicitly

**Date handling**
- [ ] `{{ date_to_id(...) }}` macro used for all YYYYMMDD integer date FK columns
- [ ] Raw timestamps (`_at`) only in staging/intermediate — absent from mart final selects
- [ ] Marts expose `_date_id` FK columns only

**YAML**
- [ ] Model entry exists in the layer's `_models.yml`
- [ ] `description` includes the grain statement
- [ ] All columns documented with `data_type` and `description`
- [ ] `not_null` test on all key columns
- [ ] `relationships` test on all FK columns
- [ ] `unique` on primary key columns

**Layer rules**
- [ ] Intermediate models do not reference mart models
- [ ] Materialization matches the layer (staging=view, intermediate=ephemeral, mart=table)

Report all violations with the file and line reference. Propose fixes but do not apply them without confirmation.
