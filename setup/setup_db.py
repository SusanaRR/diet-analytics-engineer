"""
setup_db.py
One-time setup: creates all schemas and raw tables for the pipeline.
Run once via the setup DAG (schedule=None) before any other DAG is triggered.

Usage:
    python setup/setup_db.py

Requires a .env file with:
    TARGET_ENV=dev
"""

import os
import sys

_setup_dir    = os.path.dirname(os.path.realpath(__file__))
_project_root = os.path.dirname(_setup_dir)
sys.path.insert(0, _project_root)

from dotenv import load_dotenv
from utils.db import get_env_prefix, get_db_name, get_db_path, get_connection, load_sql

load_dotenv()

queries_dir = os.path.join(_setup_dir, "queries")

env_prefix = get_env_prefix()
db_name    = get_db_name(env_prefix)
db_path    = get_db_path(_project_root, db_name)


def main():
    sql  = load_sql(queries_dir, "create_tables.sql", db_name)
    conn = get_connection(db_path)
    conn.execute(sql)
    conn.close()
    print(f"Tables created in {db_path}")


if __name__ == "__main__":
    main()
