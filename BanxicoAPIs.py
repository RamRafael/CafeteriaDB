# BanxicoAPIs.py
#   Extracts economic time-series data from the Banco de
#   México SIE REST API, transforms the raw JSON into clean
#   records, and loads them into both a local CSV and a
#   MySQL database via stored procedures.
#
#   ETL flow:
#     extract_serie()  →  transform()  →  save_csv() + save_mysql()

import csv
import requests
import mysql.connector
from datetime import datetime
from config import BANXICO_TOKEN, DATA_DIR, MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB

BANXICO_URL = "https://www.banxico.org.mx/SieAPIRest/service/v1/series"   # -- base REST endpoint for all series
HEADERS     = {"Bmx-Token": BANXICO_TOKEN, "Accept": "application/json"}  # -- token auth required on every request


# SERIES — Economic indicators to pull
SERIES = {
    "SF43718": "Exchange Rate USD/MXN",     # -- spot FIX exchange rate published daily by Banxico
    "SP1":     "INPC Inflation Index",      # -- national consumer price index (base 2018 = 100)
    "SF43784": "Border Zone Minimum Wage",  # -- daily wage for the northern free-trade zone
    "SF3338":  "TIIE Interest Rate",        # -- 28-day interbank rate; proxy for loan cost to landlords
}

START_DATE  = "2000-01-01"                           # -- pull 26 years of history for trend analysis
END_DATE    = "2026-04-30"                           # -- upper bound; future dates return available data only
CSV_BANXICO = f"{DATA_DIR}/banxico_series.csv"       # -- output file; overwritten on every ETL run


# get_connection — Opens a MySQL connection
#   We use mysql_native_password because some MySQL 8+
#   servers default to caching_sha2_password, which can
#   fail without SSL. Explicit plugin avoids the mismatch.
def get_connection():
    return mysql.connector.connect(
        host        = MYSQL_HOST,
        user        = MYSQL_USER,
        password    = MYSQL_PASS,
        database    = MYSQL_DB,
        auth_plugin = "mysql_native_password"   # -- forces legacy auth to avoid SHA2 issues on plain connections
    )


# extract_serie — Downloads raw data for one series key
#   Hits the Banxico SIE endpoint for the given series ID
#   over the full date range. Returns the "datos" array or
#   an empty list on HTTP errors (fail-soft so the ETL
#   continues with the remaining series).
def extract_serie(key):
    url = f"{BANXICO_URL}/{key}/datos/{START_DATE}/{END_DATE}"   # -- builds the full series URL with date range
    res = requests.get(url, headers=HEADERS)
    if res.status_code == 200:
        return res.json()["bmx"]["series"][0].get("datos", [])   # -- navigate JSON envelope to the data array
    print(f"  [BANXICO] Error {res.status_code} on serie {key}")
    return []   # -- return empty list so the caller can skip gracefully


# transform — Cleans and normalizes raw Banxico records
#   Banxico encodes missing values as "", "N/E", or "N/D";
#   we skip those rows entirely rather than storing nulls,
#   which keeps the CSV analysis-ready without extra cleaning.
#   Dates arrive as DD/MM/YYYY; we convert to ISO 8601
#   (YYYY-MM-DD) so Pandas parses them without format hints.
def transform(key, name, records):
    clean = []
    for r in records:
        if r["dato"] in ("", "N/E", "N/D"):   # -- skip unavailable or not-applicable entries
            continue
        try:
            rec_date = datetime.strptime(r["fecha"], "%d/%m/%Y").strftime("%Y-%m-%d")   # -- reformat date to ISO 8601
            value    = float(r["dato"].replace(",", ""))                                 # -- strip thousands separator before casting
            clean.append({"serie_key": key, "serie_name": name,
                          "date": rec_date, "value": value})
        except ValueError:
            continue   # -- silently drop any record that cannot be parsed
    return clean


# save_csv — Writes all records to a single flat CSV
#   We overwrite the file on every run (mode "w") because
#   the ETL always fetches the full date range; appending
#   would create duplicates. DictWriter ensures column
#   order is consistent regardless of dict insertion order.
def save_csv(records):
    with open(CSV_BANXICO, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["serie_key", "serie_name", "date", "value"])
        writer.writeheader()
        writer.writerows(records)
    print(f"  [CSV] banxico_series.csv saved ({len(records)} records)")


# save_mysql — Persists records through stored procedures
#   All database writes go through stored procedures
#   (sp_insert_banxico, sp_insert_serie, etc.) instead of
#   raw SQL. This keeps the business logic in MySQL, makes
#   the Python layer easier to unit-test, and enforces
#   schema-level constraints (e.g. duplicate checks) in one place.
#   Sequence:
#     1. sp_log_etl_start   — opens an ETL log entry, returns log_id
#     2. sp_clear_banxico   — deletes existing Banxico rows (full refresh)
#     3. sp_insert_serie    — upserts series metadata
#     4. sp_insert_banxico  — inserts each data point
#     5. sp_log_etl_finish  — closes the log entry with row count + status
def save_mysql(records):
    conn   = get_connection()
    cursor = conn.cursor()

    cursor.callproc("sp_log_etl_start", ["banxico_etl", "Banxico API"])   # -- open ETL audit log
    conn.commit()
    for result in cursor.stored_results():
        log_id = result.fetchone()[0]   # -- capture the auto-generated log ID for the finish call

    cursor.callproc("sp_clear_banxico")   # -- wipe existing rows before re-inserting (full refresh strategy)
    conn.commit()

    for key, name in SERIES.items():
        cursor.callproc("sp_insert_serie", [key, name, "", ""])   # -- upsert series metadata row
        conn.commit()

    for r in records:
        cursor.callproc("sp_insert_banxico", [r["serie_key"], r["serie_name"],
                                              r["date"], r["value"]])   # -- insert one data point per call
        conn.commit()

    cursor.callproc("sp_log_etl_finish", [log_id, len(records), "success", None])   # -- close audit log with success
    conn.commit()
    cursor.close()
    conn.close()
    print(f"  [MySQL] {len(records)} Banxico records saved")


# load_banxico iterates over all series in SERIES, runs the full
#   Extract → Transform → Load pipeline for each, then
#   writes the aggregated results to CSV and MySQL.
#   Returns the total record count so the caller can
#   display it in Streamlit.
def load_banxico():
    print("\n[BANXICO] Starting ETL...")
    all_records = []

    for key, name in SERIES.items():
        print(f"  Extracting: {key} — {name}")
        raw   = extract_serie(key)         # -- fetch raw JSON array from Banxico
        clean = transform(key, name, raw)  # -- clean, reformat dates, cast values
        all_records.extend(clean)
        print(f"    {len(clean)} records")

    save_csv(all_records)       # -- write flat CSV for Pandas consumption in dashboard.py
    save_mysql(all_records)     # -- persist to MySQL via stored procedures

    print(f"[BANXICO] ETL complete — {len(all_records)} total records")
    return len(all_records)   # -- returned to Streamlit so it can show "X records loaded"


if __name__ == "__main__":
    load_banxico()   # -- allows running this module directly for a manual ETL trigger