"""
Page 1 — User Health

Tabs: Overview | Nutrients | Trends | Food Log | BMI
"""

import altair as alt
import streamlit as st
from db import query, CORE_SCHEMA, USER_HEALTH_SCHEMA
from filters import setup_sidebar, user_selectbox

st.set_page_config(page_title="User Health", layout="wide")
start_date, end_date = setup_sidebar()

st.title("User Health")
user_id = user_selectbox(key="health_user")

tab_overview, tab_nutrients, tab_trends, tab_food, tab_bmi = st.tabs(
    ["Overview", "Nutrients", "Trends", "Food Log", "BMI"]
)

# ── Overview ──────────────────────────────────────────────────────────────────
with tab_overview:
    user = query(f"""
        select
            dim_users.user_id,
            dim_users.country,
            dim_users.birth_date,
            dim_users.weight_kg,
            dim_users.height_cm,
            dim_users.bmi,
            dim_users.bmi_category,
            dim_users.recommended_protein_g,
            dim_date.full_date as registered_date
        from {CORE_SCHEMA}.dim_users
        inner join {CORE_SCHEMA}.dim_date
            on dim_users.registered_date_id = dim_date.date_id
        where dim_users.user_id = {user_id}
    """)

    if user.empty:
        st.error(f"No data found for user {user_id}.")
    else:
        row = user.iloc[0]
        col1, col2, col3, col4, col5 = st.columns(5)
        col1.metric("Weight",         f"{row['weight_kg']} kg")
        col2.metric("Height",         f"{row['height_cm']} cm")
        col3.metric("BMI",            f"{row['bmi']}")
        col4.metric("BMI Category",   row["bmi_category"])
        col5.metric("Protein target", f"{row['recommended_protein_g']} g/day")
        col6, col7, col8 = st.columns(3)
        col6.metric("Country",        row["country"])
        col7.metric("Birth date",     str(row["birth_date"]))
        col8.metric("Registered",     str(row["registered_date"]))

# ── Nutrients ─────────────────────────────────────────────────────────────────
with tab_nutrients:
    df_nut = query(f"""
        with daily as (
            select
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date,
                sum(fct_meal_log_nutrients.value_g) as daily_value_g
            from {USER_HEALTH_SCHEMA}.fct_meal_log_nutrients
            inner join {CORE_SCHEMA}.dim_nutrients
                on fct_meal_log_nutrients.nutrient_id = dim_nutrients.nutrient_id
            where fct_meal_log_nutrients.user_id = {user_id}
                and fct_meal_log_nutrients.logged_date between '{start_date}' and '{end_date}'
            group by
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date
        )
        select
            nutrient_name,
            logged_date,
            daily_value_g,
            round(avg(daily_value_g) over (
                partition by nutrient_id
                order by logged_date
                rows between 6 preceding and current row
            ), 2) as rolling_7d_avg_g
        from daily
        order by nutrient_name, logged_date
    """)

    if df_nut.empty:
        st.info("No data for the selected range.")
    else:
        nutrient = st.selectbox("Nutrient", df_nut["nutrient_name"].unique().tolist(), key="nut_sel")
        filtered = df_nut[df_nut["nutrient_name"] == nutrient]
        base = alt.Chart(filtered).encode(x=alt.X("logged_date:T", title="Date"))
        chart = alt.layer(
            base.mark_line(opacity=0.35, color="#4C78A8").encode(
                y=alt.Y("daily_value_g:Q", title="g"),
                tooltip=["logged_date:T", "daily_value_g:Q"],
            ),
            base.mark_line(strokeWidth=2, color="#F58518").encode(
                y=alt.Y("rolling_7d_avg_g:Q", title="g"),
                tooltip=["logged_date:T", "rolling_7d_avg_g:Q"],
            ),
        ).properties(
            title=f"{nutrient} — daily (blue) vs 7-day avg (orange)",
            height=300,
        ).interactive()
        st.altair_chart(chart, use_container_width=True)

# ── Trends ────────────────────────────────────────────────────────────────────
with tab_trends:
    df_weekly = query(f"""
        with daily as (
            select
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date,
                sum(fct_meal_log_nutrients.value_g) as daily_value_g
            from {USER_HEALTH_SCHEMA}.fct_meal_log_nutrients
            inner join {CORE_SCHEMA}.dim_nutrients
                on fct_meal_log_nutrients.nutrient_id = dim_nutrients.nutrient_id
            where fct_meal_log_nutrients.user_id = {user_id}
                and fct_meal_log_nutrients.logged_date between '{start_date}' and '{end_date}'
            group by
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date
        )
        select
            nutrient_name,
            date_trunc('week', logged_date) as week_start,
            round(avg(daily_value_g), 2)    as weekly_avg_g
        from daily
        group by nutrient_id, nutrient_name, week_start
        order by nutrient_name, week_start
    """)

    df_monthly = query(f"""
        with daily as (
            select
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date,
                sum(fct_meal_log_nutrients.value_g) as daily_value_g
            from {USER_HEALTH_SCHEMA}.fct_meal_log_nutrients
            inner join {CORE_SCHEMA}.dim_nutrients
                on fct_meal_log_nutrients.nutrient_id = dim_nutrients.nutrient_id
            where fct_meal_log_nutrients.user_id = {user_id}
                and fct_meal_log_nutrients.logged_date between '{start_date}' and '{end_date}'
            group by
                fct_meal_log_nutrients.nutrient_id,
                dim_nutrients.nutrient_name,
                fct_meal_log_nutrients.logged_date
        ),
        monthly as (
            select
                nutrient_id,
                nutrient_name,
                date_trunc('month', logged_date) as month_start,
                round(avg(daily_value_g), 2)     as monthly_avg_g
            from daily
            group by nutrient_id, nutrient_name, month_start
        )
        select
            nutrient_name,
            month_start,
            monthly_avg_g,
            round(monthly_avg_g - lag(monthly_avg_g) over (
                partition by nutrient_id order by month_start
            ), 2) as mom_delta_g
        from monthly
        order by nutrient_name, month_start
    """)

    if df_weekly.empty:
        st.info("No data for the selected range.")
    else:
        nutrient_t = st.selectbox("Nutrient", df_weekly["nutrient_name"].unique().tolist(), key="trend_sel")
        sub1, sub2 = st.tabs(["Weekly", "Monthly"])

        with sub1:
            wk = df_weekly[df_weekly["nutrient_name"] == nutrient_t].copy()
            wk = wk.sort_values("week_start")
            wk["week_label"] = wk["week_start"].dt.strftime("%Y-W%W")
            st.altair_chart(
                alt.Chart(wk).mark_bar(color="#4C78A8").encode(
                    x=alt.X("week_label:O", title="Week", sort=None,
                             axis=alt.Axis(labelAngle=-45)),
                    y=alt.Y("weekly_avg_g:Q", title="Avg g/day"),
                    tooltip=[
                        alt.Tooltip("week_label:O", title="Week"),
                        alt.Tooltip("weekly_avg_g:Q", title="Avg g/day"),
                    ],
                ).properties(height=280),
                use_container_width=True,
            )

        with sub2:
            mo = df_monthly[df_monthly["nutrient_name"] == nutrient_t].copy()
            mo = mo.sort_values("month_start")
            mo["month_label"] = mo["month_start"].dt.strftime("%b %Y")
            bar = alt.Chart(mo).mark_bar(color="#4C78A8").encode(
                x=alt.X("month_label:O", title="Month", sort=None,
                         axis=alt.Axis(labelAngle=-45)),
                y=alt.Y("monthly_avg_g:Q", title="Avg g/day"),
                tooltip=[
                    alt.Tooltip("month_label:O", title="Month"),
                    alt.Tooltip("monthly_avg_g:Q", title="Avg g/day"),
                    alt.Tooltip("mom_delta_g:Q", title="MoM delta (g)"),
                ],
            )
            delta = alt.Chart(mo).mark_line(point=True, color="#F58518", strokeWidth=2).encode(
                x=alt.X("month_label:O", sort=None),
                y=alt.Y("mom_delta_g:Q", title="MoM delta (g)"),
                tooltip=[
                    alt.Tooltip("month_label:O", title="Month"),
                    alt.Tooltip("mom_delta_g:Q", title="MoM delta (g)"),
                ],
            )
            st.altair_chart(
                alt.layer(bar, delta).resolve_scale(y="independent").properties(height=280),
                use_container_width=True,
            )
            st.caption("Orange line = month-over-month delta (right axis).")

# ── Food Log ──────────────────────────────────────────────────────────────────
with tab_food:
    df_food = query(f"""
        select
            fct_meal_logs.logged_date::date as logged_date,
            dim_meals.meal_name,
            dim_foods.description,
            fct_meal_logs.grams
        from {USER_HEALTH_SCHEMA}.fct_meal_logs
        inner join {CORE_SCHEMA}.dim_meals
            on fct_meal_logs.meal_id = dim_meals.meal_id
        inner join {USER_HEALTH_SCHEMA}.dim_foods
            on fct_meal_logs.fdc_id = dim_foods.fdc_id
        where fct_meal_logs.user_id = {user_id}
            and fct_meal_logs.logged_date between '{start_date}' and '{end_date}'
        order by fct_meal_logs.logged_date desc, dim_meals.meal_name
    """)

    if df_food.empty:
        st.info("No meals logged in the selected range.")
    else:
        import pandas as pd
        df_food["logged_date"] = pd.to_datetime(df_food["logged_date"]).dt.date
        available_dates = sorted(df_food["logged_date"].unique(), reverse=True)
        selected_date = st.selectbox(
            "Date",
            options=available_dates,
            format_func=lambda d: str(d),
        )
        day = df_food[df_food["logged_date"] == selected_date]

        col_b, col_l, col_d = st.columns(3)
        for col, meal in zip([col_b, col_l, col_d], ["breakfast", "lunch", "dinner"]):
            with col:
                st.markdown(f"**{meal.capitalize()}**")
                meal_df = day[day["meal_name"] == meal][["description", "grams"]].rename(
                    columns={"description": "Food", "grams": "g"}
                )
                st.dataframe(meal_df, use_container_width=True, hide_index=True)

# ── BMI ───────────────────────────────────────────────────────────────────────
with tab_bmi:
    df_bmi = query(f"""
        select
            dim_date.full_date as recorded_date,
            fct_bmi_evolution.weight_kg,
            fct_bmi_evolution.bmi
        from {USER_HEALTH_SCHEMA}.fct_bmi_evolution
        inner join {CORE_SCHEMA}.dim_date
            on fct_bmi_evolution.recorded_date_id = dim_date.date_id
        where fct_bmi_evolution.user_id = {user_id}
            and dim_date.full_date between '{start_date}' and '{end_date}'
        order by dim_date.full_date
    """)

    if df_bmi.empty:
        st.info("No weight log data in the selected range.")
    else:
        latest = df_bmi.iloc[-1]
        first  = df_bmi.iloc[0]
        c1, c2 = st.columns(2)
        c1.metric("Current Weight", f"{latest['weight_kg']} kg",
                  delta=f"{round(latest['weight_kg'] - first['weight_kg'], 1)} kg")
        c2.metric("Current BMI", f"{latest['bmi']}",
                  delta=f"{round(latest['bmi'] - first['bmi'], 1)}")
        st.dataframe(
            df_bmi.rename(columns={
                "recorded_date": "Date",
                "weight_kg":     "Weight (kg)",
                "bmi":           "BMI",
            }),
            use_container_width=True,
            hide_index=True,
        )
