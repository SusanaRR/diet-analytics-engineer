"""
dashboard/db.py

DuckDB connection helper for the Streamlit dashboard.
Reads TARGET_ENV from .env to resolve schema names dynamically.
"""

import os
from pathlib import Path

import duckdb
import streamlit as st
from dotenv import load_dotenv

# Load .env from project root (one level up from dashboard/)
load_dotenv(Path(__file__).parent.parent / ".env")

_PROJECT_ROOT = Path(__file__).parent.parent
_TARGET_ENV   = os.getenv("TARGET_ENV", "dev")
_DB_NAME      = f"{_TARGET_ENV}_diet_app"
_DB_PATH      = _PROJECT_ROOT / "data" / f"{_DB_NAME}.duckdb"

# Schema names mirror dbt_project.yml + profiles.yml prefix
MARTS_SCHEMA     = f"{_TARGET_ENV}_marts"
MARKETING_SCHEMA = f"{_TARGET_ENV}_marketing"


@st.cache_resource
def get_connection():
    """Return a cached read-only DuckDB connection."""
    return duckdb.connect(str(_DB_PATH), read_only=True)


def query(sql: str) -> "pd.DataFrame":
    """Run a SQL query and return a DataFrame."""
    return get_connection().execute(sql).fetchdf()
