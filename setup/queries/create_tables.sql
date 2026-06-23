-- create_tables.sql
-- One-time setup: creates all schemas and raw tables for the pipeline.
-- Run once via the setup DAG (schedule=None) before any other DAG is triggered.

-- USDA
CREATE SCHEMA IF NOT EXISTS {database}.usda;

CREATE TABLE IF NOT EXISTS {database}.usda.raw_foods (
    fdc_id INTEGER,
    loaded_at TIMESTAMPTZ DEFAULT current_timestamp,
    raw_json JSON
);

-- App events
CREATE SCHEMA IF NOT EXISTS {database}.app_events;

CREATE TABLE IF NOT EXISTS {database}.app_events.raw_meal_logs (
    user_id INTEGER,
    breakfast STRUCT(fdc_id INTEGER, grams FLOAT)[],
    lunch    STRUCT(fdc_id INTEGER, grams FLOAT)[],
    dinner   STRUCT(fdc_id INTEGER, grams FLOAT)[],
    logged_at TIMESTAMP
);
