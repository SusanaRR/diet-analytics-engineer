"""
Page 2 — Marketing Segmentation

Tab 1 — Windowed: per-user snapshot (last day / 7d / 30d)
Tab 2 — Flagged Users: daily count of flagged users per nutrient vs total users
"""

import altair as alt
import streamlit as st
from db import query, CORE_SCHEMA, MARKETING_SCHEMA
from filters import setup_sidebar, user_selectbox

st.set_page_config(page_title="Marketing", layout="wide")
start_date, end_date = setup_sidebar()

st.title("Marketing Segmentation")

tab_windowed, tab_flagged = st.tabs(["Windowed (per user)", "Flagged Users (all)"])

# ── Tab 1: windowed per-user snapshot ────────────────────────────────────────
with tab_windowed:
    user_id = user_selectbox(key="mkt_user")
    windowed = query(f"""
        select
            dim_nutrients.nutrient_name,
            fct_user_segments_windowed.last_day_g,
            fct_user_segments_windowed.last_7d_avg_g,
            fct_user_segments_windowed.last_30d_avg_g,
            fct_user_segments_windowed.threshold_g,
            fct_user_segments_windowed.segment_label,
            fct_user_segments_windowed.is_flagged_last_day,
            fct_user_segments_windowed.is_flagged_last_7d,
            fct_user_segments_windowed.is_flagged_last_30d
        from {MARKETING_SCHEMA}.fct_user_segments_windowed
        inner join {CORE_SCHEMA}.dim_nutrients
            on fct_user_segments_windowed.nutrient_id = dim_nutrients.nutrient_id
        where fct_user_segments_windowed.user_id = {user_id}
        order by dim_nutrients.nutrient_name
    """)

    if windowed.empty:
        st.info("No windowed segment data available.")
    else:
        st.dataframe(
            windowed[[
                "nutrient_name",  "threshold_g",
                "last_day_g",     "is_flagged_last_day",
                "last_7d_avg_g",  "is_flagged_last_7d",
                "last_30d_avg_g", "is_flagged_last_30d",
            ]].rename(columns={
                "nutrient_name":       "Nutrient",
                "threshold_g":         "Threshold (g)",
                "last_day_g":          "Last day (g)",
                "is_flagged_last_day": "Flagged (1d)",
                "last_7d_avg_g":       "7d avg (g)",
                "is_flagged_last_7d":  "Flagged (7d)",
                "last_30d_avg_g":      "30d avg (g)",
                "is_flagged_last_30d": "Flagged (30d)",
            }),
            use_container_width=True,
            hide_index=True,
        )

# ── Tab 2: daily flagged user count across all users ─────────────────────────
with tab_flagged:
    st.caption("Across all users — not filtered by the user selector.")

    df_counts = query(f"""
        select
            dim_nutrients.nutrient_name,
            fct_user_segments.logged_date,
            count(*)                                                      as total_users,
            sum(case when fct_user_segments.is_flagged then 1 else 0 end) as flagged_users
        from {MARKETING_SCHEMA}.fct_user_segments
        inner join {CORE_SCHEMA}.dim_nutrients
            on fct_user_segments.nutrient_id = dim_nutrients.nutrient_id
        where fct_user_segments.logged_date between '{start_date}' and '{end_date}'
        group by
            fct_user_segments.nutrient_id,
            dim_nutrients.nutrient_name,
            fct_user_segments.logged_date
        order by dim_nutrients.nutrient_name, fct_user_segments.logged_date
    """)

    if df_counts.empty:
        st.info("No segment data for the selected range.")
    else:
        nutrient = st.selectbox(
            "Nutrient", df_counts["nutrient_name"].unique().tolist(), key="flag_nut"
        )
        df_n = df_counts[df_counts["nutrient_name"] == nutrient]

        bars = alt.Chart(df_n).mark_bar(color="#4C78A8", opacity=0.7).encode(
            x=alt.X("logged_date:T", title="Date"),
            y=alt.Y("flagged_users:Q", title="Users", scale=alt.Scale(domain=[0, df_n["total_users"].max()])),
            tooltip=[
                alt.Tooltip("logged_date:T", title="Date"),
                alt.Tooltip("flagged_users:Q", title="Flagged users"),
                alt.Tooltip("total_users:Q", title="Total users"),
            ],
        )

        total_line = alt.Chart(df_n).mark_line(color="#F58518", strokeWidth=2, strokeDash=[4, 2]).encode(
            x="logged_date:T",
            y=alt.Y("total_users:Q"),
            tooltip=[
                alt.Tooltip("logged_date:T", title="Date"),
                alt.Tooltip("total_users:Q", title="Total users"),
            ],
        )

        st.altair_chart(
            alt.layer(bars, total_line).properties(
                title=f"{nutrient} — flagged users (bars) vs total users (dashed line)",
                height=320,
            ).interactive(),
            use_container_width=True,
        )
