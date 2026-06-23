"""
dashboard/filters.py

Shared helpers — call setup_sidebar() at the top of each page.
"""

from datetime import date

import streamlit as st
from db import query, MARTS_SCHEMA

APP_LAUNCH_DATE = date(2026, 5, 1)

SMALL_FONT_CSS = """
<style>
    html, body, [class*="css"]          { font-size: 13px !important; }
    h1                                  { font-size: 1.3rem !important; }
    h2, h3                              { font-size: 1.05rem !important; }
    [data-testid="metric-container"]    { padding: 4px 8px !important; }
    [data-testid="stMetricValue"]       { font-size: 1rem !important; }
    [data-testid="stMetricLabel"]       { font-size: 0.75rem !important; }
    [data-testid="stMetricDelta"]       { font-size: 0.75rem !important; }
</style>
"""


def setup_sidebar():
    """Render CSS + date range sidebar. Returns (start_date, end_date)."""
    st.markdown(SMALL_FONT_CSS, unsafe_allow_html=True)

    max_row = query(f"""
        select max(logged_date) as max_date from {MARTS_SCHEMA}.fct_meal_logs
    """)
    max_date = max_row["max_date"].iloc[0]

    with st.sidebar:
        st.header("Filters")

        selected_dates = st.date_input(
            "Date range",
            value=(APP_LAUNCH_DATE, max_date),
            min_value=APP_LAUNCH_DATE,
            max_value=max_date,
        )

        start_date, end_date = (
            selected_dates if len(selected_dates) == 2
            else (selected_dates[0], selected_dates[0])
        )

    return start_date, end_date


def user_selectbox(key="user_sel"):
    """Render a user selectbox inline on the page. Returns selected user_id."""
    users = query(f"""
        select user_id from {MARTS_SCHEMA}.dim_users order by user_id
    """)
    return st.selectbox(
        "User",
        options=users["user_id"].tolist(),
        format_func=lambda x: f"User {x}",
        key=key,
    )
