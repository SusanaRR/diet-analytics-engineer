"""
generate_historical_meal_logs.py

Generates synthetic meal-logging events for each user from their individual
registration date (read from the users seed CSV) to yesterday.

One row per user per day. Each row contains breakfast, lunch, and dinner arrays
of 3 random food items with random serving sizes between 80g and 250g.

Foods are sampled from real Foundation Foods already loaded into raw_foods,
so every fdc_id generated here references a real food.

Idempotent: truncates raw_meal_logs before inserting all historical rows.

Assumes all tables already exist — run setup/setup_db.py once before this script.

Usage:
    python app_events/generate_historical_meal_logs.py
"""

import csv
import os
import sys
import random
from datetime import date, datetime, timedelta

_app_events_dir = os.path.dirname(os.path.realpath(__file__))
_project_root   = os.path.dirname(_app_events_dir)
sys.path.insert(0, _project_root)

import pandas as pd
from dotenv import load_dotenv
from utils.db import get_env_prefix, get_db_name, get_db_path, get_connection, load_sql

load_dotenv()

ITEMS_PER_MEAL = 3
MEAL_TYPES     = ["breakfast", "lunch", "dinner"]
MIN_GRAMS      = 80
MAX_GRAMS      = 250

queries_dir = os.path.join(_app_events_dir, "queries")
seeds_dir   = os.path.join(_project_root, "diet_dbt", "seeds")

env_prefix = get_env_prefix()
db_name    = get_db_name(env_prefix)
db_path    = get_db_path(_project_root, db_name)


def get_valid_fdc_ids(conn):
    """Pull real food ids from raw_foods so generated logs always reference real foods."""
    return conn.execute(load_sql(queries_dir, "01_get_fdc_ids.sql", db_name)).df()["fdc_id"].tolist()


def load_user_registrations():
    """Read user_id and registration date from the users seed CSV."""
    users = []
    with open(os.path.join(seeds_dir, "users.csv")) as f:
        for row in csv.DictReader(f):
            # datetime.fromisoformat handles the +02:00 offset correctly.
            registered_date = datetime.fromisoformat(row["registered_at"]).date()
            users.append({
                "user_id": int(row["user_id"]),
                "registered_date": registered_date,
            })
    return users


def random_logged_at(log_date):
    """Users log retrospectively once a day — pick a plausible evening time."""
    hour   = random.randint(7, 23)
    minute = random.randint(0, 59)
    return datetime.combine(log_date, datetime.min.time()) + timedelta(hours=hour, minutes=minute)


def generate_historical_logs(users, fdc_ids, end_date):
    """One row per user per day from their registration date to end_date (inclusive)."""
    rows = []
    for user in users:
        current = user["registered_date"]
        while current <= end_date:
            row = {"user_id": user["user_id"]}
            for meal in MEAL_TYPES:
                row[meal] = [
                    {"fdc_id": fdc_id, "grams": random.randint(MIN_GRAMS, MAX_GRAMS)}
                    for fdc_id in random.sample(fdc_ids, ITEMS_PER_MEAL)
                ]
            row["logged_at"] = random_logged_at(current)
            rows.append(row)
            current += timedelta(days=1)
    return pd.DataFrame(rows)


def store_meal_logs(df, conn):
    """Insert all rows — not safe to re-run."""
    conn.execute(load_sql(queries_dir, "03_insert_meal_logs.sql", db_name))


def main():
    end_date = date.today() - timedelta(days=1)

    conn    = get_connection(db_path)
    fdc_ids = get_valid_fdc_ids(conn)
    users   = load_user_registrations()
    df      = generate_historical_logs(users, fdc_ids, end_date)
    store_meal_logs(df, conn)
    conn.close()

    print(f"Generated {len(df)} meal log rows for {len(users)} users up to {end_date}.")
    for user in users:
        if user["registered_date"] <= end_date:
            days = (end_date - user["registered_date"]).days + 1
            print(f"  user_id={user['user_id']}: {days} days ({user['registered_date']} → {end_date})")


if __name__ == "__main__":
    main()
