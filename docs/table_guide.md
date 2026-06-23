# Table Guide

Practical reference for the mart layer. For dimensional design decisions (bus matrix, grain statements, SCD types) see [dimensional_model.md](dimensional_model.md).

---

## Dimensions

### `dim_date`
**Schema:** `dev_core`

One row per calendar date from 2019-01-01 to 2027-12-31. All fact tables join here via a `_date_id` FK (YYYYMMDD integer). Start date covers USDA publication dates which predate the app launch.

Use when you need date attributes (year, month, week, day name, is_weekend) without computing them inline in every query.

```
date_id   | full_date  | year | month | month_name | week_of_year | day_name | is_weekend
20260623  | 2026-06-23 | 2026 |   6   |    June    |      26      |  Tuesday |   false
```

---

### `dim_users`
**Schema:** `dev_core`

One row per user. Holds the current snapshot of each user's profile — most recent weight, BMI, BMI category, and personalised protein recommendation. History is tracked separately in `fct_bmi_evolution`.

Use when you need user attributes to enrich a fact table, or to compute the personalised protein threshold (`recommended_protein_g = weight_kg × 0.8`).

```
user_id | country | birth_date | weight_kg | height_cm | bmi  | bmi_category  | recommended_protein_g | registered_date_id
  1     |  Spain  | 1990-03-15 |   72.5    |   170.0   | 25.1 | Normal weight |         58.0          |      20240301
```

Commonly joined with: all fact tables on `user_id`.

---

### `dim_foods`
**Schema:** `dev_core`

One row per USDA Foundation Food, with macro nutrient content per 100g. Source is the USDA FoodData Central API — `fdc_id` is the stable natural key. Nutrient values describe the food itself, not a logged serving.

Use when you need food descriptions or nutrient content per 100g. For actual intake (scaled by serving size), use `fct_meal_log_nutrients` instead.

```
fdc_id | description          | protein_g | fat_g | carbohydrate_g | fiber_g | total_sugar_g
 2341  | Chicken breast, raw  |   23.1    |  2.6  |      0.0       |   0.0   |     0.0
```

Commonly joined with: `fct_meal_logs` on `fdc_id`.

---

### `dim_meals`
**Schema:** `dev_core`

One row per meal type (breakfast, lunch, dinner). Simple lookup — maps `meal_id` to a human-readable name.

```
meal_id | meal_name
   1    | breakfast
   2    | lunch
   3    | dinner
```

Commonly joined with: `fct_meal_logs`, `fct_meal_log_nutrients` on `meal_id`.

---

### `dim_nutrients`
**Schema:** `dev_core`

One row per tracked nutrient. Maps the sequential `nutrient_id` used across fact tables to the USDA nutrient code, human-readable name, and unit.

```
nutrient_id | usda_nutrient_id | nutrient_name | unit
     1      |       203        |    Protein    |  g
     2      |       204        |      Fat      |  g
     3      |       205        |  Carbohydrate |  g
     4      |       291        |     Fiber     |  g
     5      |       269        |  Total Sugar  |  g
```

Commonly joined with: `fct_meal_log_nutrients`, `fct_user_segments`, `fct_user_segments_windowed` on `nutrient_id`.

---

## Facts

### `fct_meal_logs`
**Schema:** `dev_user_health`

One row per food item per meal per day per user. Records *what was eaten and how many grams* — the raw meal log before any nutrient calculation. This is the finest-grain table in the food logging domain.

Use when you want to know what someone ate (food items, serving sizes, meal breakdown). For nutritional intake, use `fct_meal_log_nutrients`.

```
user_id | meal_id | fdc_id | grams | logged_date | logged_date_id
   1    |    1    |  2341  |  150  | 2026-06-23  |   20260623
   1    |    1    |  8823  |  200  | 2026-06-23  |   20260623
```

Commonly joined with: `dim_foods` on `fdc_id`, `dim_meals` on `meal_id`, `dim_users` on `user_id`.

---

### `fct_meal_log_nutrients`
**Schema:** `dev_user_health`

One row per nutrient per meal per day per user. Derived from `fct_meal_logs` — nutrient values per 100g from `dim_foods` are scaled by the actual serving size logged, then summed across all food items in each meal.

Each row in `fct_meal_logs` expands into 5 rows here (one per tracked nutrient). Use this table for all nutritional intake analysis.

```
user_id | meal_id | nutrient_id | value_g | logged_date | logged_date_id
   1    |    1    |      1      |  34.7   | 2026-06-23  |   20260623   ← protein from breakfast
   1    |    1    |      2      |   8.2   | 2026-06-23  |   20260623   ← fat from breakfast
   1    |    2    |      1      |  28.1   | 2026-06-23  |   20260623   ← protein from lunch
```

Commonly joined with: `dim_nutrients` on `nutrient_id`, `dim_users` on `user_id`, `dim_meals` on `meal_id`.

---

### `fct_user_segments`
**Schema:** `dev_marketing`

One row per user per nutrient per day. Classifies whether a user's daily intake is within the recommended range for each nutrient. Carbohydrate is tracked but has no segment defined and is excluded.

Use when you need the full daily history of segment flags — for trends, cohort analysis, or counting flagged days over a period.

```
user_id | nutrient_id | logged_date | daily_value_g | threshold_g | threshold_type | segment_label | is_flagged
   1    |      1      | 2026-06-23  |     62.4      |    58.0     |      min       |  low_protein  |   false
   1    |      2      | 2026-06-23  |     92.1      |    78.0     |      max       |   high_fat    |   true
```

Commonly joined with: `dim_nutrients` on `nutrient_id`, `dim_users` on `user_id`.

---

### `fct_user_segments_windowed`
**Schema:** `dev_marketing`

One row per user per nutrient — a pre-computed snapshot of intake averages across three windows: last day, last 7 days, last 30 days. Anchored to each user's most recent logged date.

Use instead of `fct_user_segments` when you want a summary view without aggregating daily history yourself. Best for segmentation dashboards and targeting lists.

```
user_id | nutrient_id | last_day_g | last_7d_avg_g | last_30d_avg_g | threshold_g | is_flagged_last_day | is_flagged_last_7d | is_flagged_last_30d
   1    |      1      |    62.4    |     59.1      |     57.3       |    58.0     |        false        |       false        |        true
```

Commonly joined with: `dim_nutrients` on `nutrient_id`, `dim_users` on `user_id`.

---

### `fct_bmi_evolution`
**Schema:** `dev_user_health`

One row per weight log entry per user. Tracks BMI over time as the user checks in with a new weight. Each entry is independent — there is no link between entries beyond `user_id`.

Use when you want to show BMI trends over time. For the current BMI only, use `dim_users` instead.

```
weight_log_id | user_id | weight_kg | height_cm | bmi  | recorded_date_id
   abc123      |    1    |   72.5    |   170.0   | 25.1 |    20260501
   def456      |    1    |   71.0    |   170.0   | 24.6 |    20260515
```

Commonly joined with: `dim_users` on `user_id`, `dim_date` on `recorded_date_id`.

---

## Snapshot

### `dim_foods_snapshot`
**Schema:** `snapshots`

SCD Type 2 history of `dim_foods`. A new row is added whenever any tracked nutrient value changes for a given food. `dbt_valid_to` is null for the currently active row.

Use when you need to know what the nutrient values were at a specific point in time — for example, to reconstruct historical intake calculations accurately after a USDA data update.

```
dbt_scd_id | fdc_id | protein_g | dbt_valid_from           | dbt_valid_to
  xyz789   |  2341  |   22.8    | 2026-01-15 00:00:00+00   | 2026-06-01 00:00:00+00
  abc123   |  2341  |   23.1    | 2026-06-01 00:00:00+00   | null  ← current
```
