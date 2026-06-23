"""
extract.py
Pulls Foundation Foods (abridged) from /foods/list and inserts each
food's raw JSON as-is into DuckDB, one row per food.
Assumes the raw_foods table already exists - run setup/create_tables.sql once
via the setup DAG before this script is ever called.

Usage:
    python usda/extract.py

Requires a .env file with:
    FDC_API_KEY=your_key_here
    TARGET_ENV=dev
"""

import json
import os
import sys

_usda_dir     = os.path.dirname(os.path.realpath(__file__))
_project_root = os.path.dirname(_usda_dir)
sys.path.insert(0, _project_root)

import requests
from dotenv import load_dotenv
from utils.db import get_env_prefix, get_db_name, get_db_path, get_connection, load_sql

load_dotenv()

queries_dir = os.path.join(_usda_dir, "queries")

env_prefix = get_env_prefix()
db_name    = get_db_name(env_prefix)
db_path    = get_db_path(_project_root, db_name)

# TODO
# Set api key in secrets
# END TODO
api_key  = os.getenv("FDC_API_KEY")
base_url = "https://api.nal.usda.gov/fdc/v1"


# the API responded, but with an error status
class FDCAPIExtractionException(Exception):
    pass

# the request never even got a response, a network-level problem
class RequestAPIExtractionException(Exception):
    pass


def get_response(end_point, params, api_key, base_url):
    """Generator that pages through an FDC endpoint, yielding one response per page."""
    url       = base_url + end_point
    page_size = params.get("pageSize", 50)
    params    = {**params, "api_key": api_key, "pageNumber": 1}

    with requests.Session() as session:
        session.params = params
        while True:
            try:
                print(f"Requesting {url} with params={session.params}")
                response = session.get(url, timeout=(3.05, 90))
                # TODO check if 200 is it fine to leave
                if response.status_code == 200:
                # END TODO
                    data = response.json()
                    print(f"Page {session.params['pageNumber']} returned {len(data)} records")
                    yield response
                    if len(data) < page_size:
                        break
                    session.params["pageNumber"] += 1
                else:
                    raise FDCAPIExtractionException(
                        f"API extraction failed with status_code={response.status_code}"
                    )
            except requests.RequestException as err:
                raise RequestAPIExtractionException("Fatal error occurred", err) from err


def store_raw_foods(responses, db_path):
    """Insert each food's raw JSON exactly as received, one row per food."""
    params = [
        {"fdc_id": food.get("fdcId"), "raw_json": json.dumps(food)}
        for response in responses
        for food in response.json()
    ]

    sql  = load_sql(queries_dir, "insert_raw_foods.sql", db_name)
    conn = get_connection(db_path)
    conn.executemany(sql, params)
    conn.close()

    print(f"Stored {len(params)} raw food records into {db_path}")


def main():
    if not api_key:
        raise SystemExit("FDC_API_KEY not found. Add it to your .env file.")

    responses = get_response(
        end_point="/foods/list",
        params={"dataType": "SR Legacy", "pageSize": 200}, # check about page size, as mentions on swagger the max is 50
        api_key=api_key,
        base_url=base_url,
    )
    store_raw_foods(responses, db_path)


if __name__ == "__main__":
    main()
