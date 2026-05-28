# Latti Coffee House & Deli — Gentrification Analysis

An end-to-end data extraction and visualization project analyzing gentrification patterns in Tijuana, Baja California, compared against CDMX, Monterrey, and Guadalajara. Built for the *Extracción de Datos* course using Python, MySQL, and Streamlit.

---

## Research Questions

1. Which city has the most expensive commercial rental prices?
2. How has rent changed over time adjusted for inflation (INPC)?
3. How many minimum wages does it take to rent in each city?
4. How does the USD/MXN exchange rate affect dollar-priced rents in Tijuana?
5. Which neighborhoods concentrate the highest rents?

---

## Project Structure

```
CafeteriaProject/
├── .env                    # Environment variables (DB credentials, Banxico token)
├── config.py               # Loads .env once — all other files import from here
├── BanxicoAPIs.py          # ETL: extracts economic series from Banxico SIE API
├── scraper_tijuana.py      # ETL: scrapes rental listings from Vivanuncios.com.mx
├── dashboard.py            # Streamlit page rendering module
├── main.py                 # Streamlit entry point
├── CafeteriaDB_final.sql   # Full database schema, procedures, triggers and views
├── data/                   # Generated CSV files (created at runtime)
│   ├── banxico_series.csv
│   ├── tijuana_mn.csv
│   ├── tijuana_usd.csv
│   ├── cdmx_mn.csv
│   ├── monterrey_mn.csv
│   └── guadalajara_mn.csv
```

---

## Database — MySQL

**Database name:** `cafeteria`

### Entities (10 tables + Audit)

| Table | Description |
|---|---|
| `City` | The 4 cities analyzed. Tijuana is flagged as border city |
| `Neighborhood` | Populated automatically during scraping via stored procedure |
| `ScrapedSession` | One session per city per scraping run — tracks pages and status |
| `ScrapedData` | Raw text extracted from each listing before cleaning |
| `RentalListing` | Cleaned structured listing: price, currency, neighborhood |
| `BanxicoSerie` | Catalog of the 4 economic series from Banxico API |
| `BanxicoData` | Historical values per series and date (~13,882 records) |
| `CurrencySnapshot` | USD/MXN snapshots derived from BanxicoData |
| `InflationIndex` | Annual INPC averages derived from BanxicoData |
| `ETLLog` | Tracks every ETL execution with status and record count |
| `Audit` | Automatic audit trail populated by triggers only |

### Views (6)

| View | Purpose |
|---|---|
| `vw_banxico_annual_trend` | Annual averages per economic indicator |
| `vw_rental_by_city` | Rental price summary by city and currency |
| `vw_top_neighborhoods` | Most expensive neighborhoods per city |
| `vw_exchange_rate_annual` | USD/MXN annual average from Banxico |
| `vw_etl_summary` | Health check — runs, records loaded, failures |
| `vw_rental_full_detail` | Full listing detail with city and neighborhood |

### Stored Procedures (13)

| Procedure | Description |
|---|---|
| `sp_insert_banxico` | Inserts one Banxico data record |
| `sp_insert_scraped_data` | Stores raw listing text |
| `sp_insert_rental` | Cleans and inserts a rental listing; auto-creates neighborhood if new |
| `sp_start_session` | Opens a scraping session, returns `session_id` via SELECT |
| `sp_close_session` | Closes session with final page count and status |
| `sp_log_etl_start` | Opens an ETL log entry, returns `log_id` via SELECT |
| `sp_log_etl_finish` | Closes ETL log with record count and status |
| `sp_clear_banxico` | Wipes Banxico data (DELETE ordered to respect FK constraints) |
| `sp_clear_scraped` | Wipes all scraping data in FK-safe order |
| `sp_get_banxico` | Returns all Banxico records ordered by date |
| `sp_get_scraped_data` | Returns raw scraped records |
| `sp_get_rentals` | Returns full rental detail via `vw_rental_full_detail` |
| `sp_insert_serie` | Adds a Banxico serie to the catalog (INSERT IGNORE) |

### Triggers (6)

| Trigger | Event |
|---|---|
| `trg_banxico_insert` | AFTER INSERT on BanxicoData |
| `trg_banxico_delete` | AFTER DELETE on BanxicoData |
| `trg_rental_insert` | AFTER INSERT on RentalListing |
| `trg_rental_delete` | AFTER DELETE on RentalListing |
| `trg_session_update` | AFTER UPDATE on ScrapedSession |
| `trg_etl_update` | AFTER UPDATE on ETLLog |

> All triggers write to the `Audit` table automatically — no manual inserts from Python.

---

## Python Modules

### `config.py`
Loads the `.env` file once and exposes all credentials and paths as module-level constants. Every other file imports from here instead of calling `load_dotenv()` individually.

```python
from config import MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, BANXICO_TOKEN, DATA_DIR
```

### `BanxicoAPIs.py`
Extracts 4 economic series from the [Banxico SIE API](https://www.banxico.org.mx/SieAPIRest/service/v1/):

| Serie Key | Name | Frequency |
|---|---|---|
| SF43718 | Exchange Rate USD/MXN | Daily |
| SP1 | INPC Inflation Index | Monthly |
| SF43784 | Border Zone Minimum Wage | Annual |
| SF3338 | TIIE Interest Rate | Daily |

**ETL flow:**
1. **Extract** — calls Banxico API for each serie (2000–2026)
2. **Transform** — parses `DD/MM/YYYY` dates, cleans comma-formatted values
3. **Load CSV** — saves to `data/banxico_series.csv`
4. **Load MySQL** — inserts via `sp_insert_banxico` (no direct SQL from Python)

Run directly from PyCharm:
```
▶️ Run BanxicoAPIs.py
```

### `scraper_tijuana.py`
Scrapes commercial rental listings from [Vivanuncios.com.mx](https://www.vivanuncios.com.mx) for 4 cities using `requests` + `BeautifulSoup`.

**Cities and URLs:**

| City | Listings available |
|---|---|
| Tijuana | ~216 |
| CDMX | ~2,322 |
| Monterrey | ~1,572 |
| Guadalajara | ~752 |

**ETL flow:**
1. **Extract** — fetches 30 listings per page using `div.postingsList-module__card-container`
2. **Transform** — parses price from `[data-qa='POSTING_CARD_PRICE']`, splits by currency (MN/USD)
3. **Load CSV** — saves `{city}_mn.csv` and `{city}_usd.csv` to `data/`
4. **Load MySQL** — inserts via `sp_insert_scraped_data` and `sp_insert_rental`

Run directly from PyCharm:
```
▶️ Run scraper_tijuana.py
```

### `dashboard.py`
Streamlit page module. Contains 6 `page_*()` functions called by `main.py`:

| Function | Page | Research Question |
|---|---|---|
| `page_home()` | Home | Project overview |
| `page_comparison()` | City Comparison | Q1 — most expensive city |
| `page_calculator()` | Calculator + Inflation | Q2 + Q5 |
| `page_wages()` | Minimum Wage vs Rent | Q3 |
| `page_exchange_rate()` | Exchange Rate | Q4 |
| `page_overview()` | General Overview | Executive summary |

Reads from CSV files in `data/` for performance. Converts USD listings to MN using the latest Banxico exchange rate so all cities are comparable.

### `main.py`
Streamlit entry point. Applies global CSS, sets up the sidebar navigation, and routes to the correct `page_*()` function.

```bash
streamlit run main.py
```

---

## Setup

### Requirements

```bash
pip install streamlit pandas plotly requests beautifulsoup4 mysql-connector-python python-dotenv
```

### Environment variables (`.env`)

```
MYSQL_HOST=localhost
MYSQL_USER=root
MYSQL_PASS=your_password
MYSQL_DB=cafeteria
BANXICO_TOKEN=your_banxico_token
```

### Run order

1. Execute `CafeteriaDB_final.sql` in MySQL Workbench to create the database
2. Run `BanxicoAPIs.py` in PyCharm to load economic data
3. Run `scraper_tijuana.py` in PyCharm to load rental listings
4. Run the dashboard:

```bash
streamlit run main.py
```

---

## Data Sources

| Source | Type | Data |
|---|---|---|
| [Banxico SIE API](https://www.banxico.org.mx) | REST API | Exchange rate, INPC, wages, TIIE |
| [Vivanuncios.com.mx](https://www.vivanuncios.com.mx) | Web scraping | Commercial rental listings |

---

*Project developed for the Extracción de Datos course — 5th semester, 2026.*
