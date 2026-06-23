"""
generate_meal_logs.py
Generates synthetic meal-logging events for today's date.
One row per user per meal type (breakfast, lunch, dinner).

Foods are randomly sampled from real Foundation Foods already loaded
into raw_foods, so every fdc_id generated here references a real food.
Each food item has a random serving size between 80g and 250g.
User ids are hardcoded as 1-10 to match the users seed — demo simplification.

Truncates raw_meal_logs before inserting, so the script is safe to re-run
on the same day without producing duplicates. Historical data is preserved
in the incremental mart tables (fct_meal_logs, fct_meal_log_nutrients).

Assumes all tables already exist - run setup/setup_db.py once before
this script is ever called.

Usage:
    python app_events/generate_meal_logs.py
"""

import os
import sys
import random
from datetime import date, datetime, timedelta
import pandas as pd

_app_events_dir = os.path.dirname(os.path.realpath(__file__))
_project_root   = os.path.dirname(_app_events_dir)
sys.path.insert(0, _project_root)


from dotenv import load_dotenv
from utils.db import get_env_prefix, get_db_name, get_db_path, get_connection, load_sql

load_dotenv()

ITEMS_PER_MEAL = 3
MEAL_TYPES     = ["breakfast", "lunch", "dinner"]
NUM_USERS      = 10       # matches the users seed (user_id 1-10)
MIN_GRAMS      = 80
MAX_GRAMS      = 250

queries_dir = os.path.join(_app_events_dir, "queries")

env_prefix = get_env_prefix()
db_name    = get_db_name(env_prefix)
db_path    = get_db_path(_project_root, db_name)


def get_valid_fdc_ids(conn):
    """Pull real food ids from dim_foods so generated logs always reference real foods."""
    return conn.execute(load_sql(queries_dir, "01_get_fdc_ids.sql", db_name)).df()["fdc_id"].tolist()


def random_logged_at(log_date):
    """Users log retrospectively, once a day - pick a plausible time they'd sit down with the app."""
    hour   = random.randint(7, 23)
    minute = random.randint(0, 59)
    return datetime.combine(log_date, datetime.min.time()) + timedelta(hours=hour, minutes=minute)


def generate_meal_logs(num_users, fdc_ids):
    """One row per user for today, with a list of fdc_ids logged for each meal."""
    today = date.today()
    rows  = []

    for user_id in range(1, num_users + 1):
        row = {"user_id": user_id}
        for meal in MEAL_TYPES:
            row[meal] = [
                {"fdc_id": fdc_id, "grams": random.randint(MIN_GRAMS, MAX_GRAMS)}
                for fdc_id in random.sample(fdc_ids, ITEMS_PER_MEAL)
            ]
        row["logged_at"] = random_logged_at(today)
        rows.append(row)

    return pd.DataFrame(rows)


def store_meal_logs(df, conn):
    """Truncate raw_meal_logs then insert today's meal logs."""
    conn.execute(load_sql(queries_dir, "02_truncate_meal_logs.sql", db_name))
    conn.execute(load_sql(queries_dir, "03_insert_meal_logs.sql", db_name))


def main():
    conn    = get_connection(db_path)
    fdc_ids = get_valid_fdc_ids(conn)
    df      = generate_meal_logs(NUM_USERS, fdc_ids)
    store_meal_logs(df, conn)
    conn.close()
    print(f"Generated and stored {len(df)} meal log rows for {NUM_USERS} users for {date.today()}.")
    print(df)


if __name__ == "__main__":
    main()
