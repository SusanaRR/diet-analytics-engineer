"""
utils/db.py
Shared helpers used across extraction and setup scripts.

    get_env_prefix()            — reads TARGET_ENV, fails fast if missing
    get_db_name(env_prefix)     — builds "<env>_diet_app"
    get_db_path(root, db_name)  — builds path to the DuckDB file under data/
    get_connection(db_path)     — opens and returns a DuckDB connection
    load_sql(queries_dir, filename, db_name) — loads a .sql file and substitutes {database}
"""

import os

import duckdb


ALLOWED_ENVS = {"dev", "prod"}


def get_env_prefix() -> str:
    """Read TARGET_ENV from the environment. Raise SystemExit if missing or invalid."""
    env_prefix = os.getenv("TARGET_ENV")
    if not env_prefix:
        raise SystemExit(
            "TARGET_ENV not set. Add it to your .env file. (Example: TARGET_ENV=dev)"
        )
    if env_prefix not in ALLOWED_ENVS:
        raise SystemExit(
            f"TARGET_ENV must be one of {ALLOWED_ENVS}, got: {env_prefix!r}"
        )
    return env_prefix


def get_db_name(env_prefix: str) -> str:
    """Build the database name from the environment prefix."""
    return f"{env_prefix}_diet_app"


def get_db_path(project_root: str, db_name: str) -> str:
    """Build the absolute path to the DuckDB file."""
    return os.path.join(project_root, "data", f"{db_name}.duckdb")


def get_connection(db_path: str) -> duckdb.DuckDBPyConnection:
    """Open and return a DuckDB connection. Caller is responsible for closing."""
    return duckdb.connect(db_path)


def load_sql(queries_dir: str, filename: str, db_name: str) -> str:
    """Load a SQL file and substitute the {database} placeholder."""
    return open(os.path.join(queries_dir, filename)).read().format(database=db_name)
