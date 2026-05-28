# main.py — Application Entry Point
#     1. Apply global CSS theming (warm café palette).
#     2. Verify that required CSV files already exist.
#     3. Render the sidebar navigation.
#     4. Route the user to the correct dashboard page.
#   Run with: streamlit run main.py

import os
import streamlit as st
from BanxicoAPIs import load_banxico                         # -- ETL function: pulls Banxico series → CSV + MySQL
from scraper_tijuana import scrape_vivanuncios as scrape_inmuebles24   # -- aliased for clarity; same scraping logic
from config import DATA_DIR                                  # -- resolved path to the /data folder
import dashboard                                             # -- page-rendering functions live here

st.set_page_config(page_title="Latti Coffee Dashboard", layout="wide", page_icon="☕")
# -- wide layout maximises chart width; page_icon appears on the browser tab

# -------------------------------------------------------
# Global CSS — Warm Café Theme
#   We inject custom CSS via st.markdown(unsafe_allow_html)
#   because Streamlit's native theming options are limited.
#   All selectors below override the default dark/light theme
#   with a cream-and-green palette matching the Latti brand.
# -------------------------------------------------------
st.markdown(""" 
    <style> 
    .stApp { background-color: #FDFBF7 !important; }                     /* -- main canvas: warm off-white */
    [data-testid="stSidebar"] { background-color: #E2EFDA !important; }  /* -- sidebar: soft sage green */
    [data-testid="stSidebar"] * { color: #2E4D23 !important; }           /* -- sidebar text: deep forest green */
    h1, h2, h3, h4, p, li, span, label { 
        color: #4B3621 !important;                                        /* -- body text: warm espresso brown */
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
    } 
    div[data-baseweb="select"] > div { 
        background-color: #FFFFFF !important; 
        border: 2px solid #A9D18E !important;                             /* -- select box border: mint green accent */
    } 
    div[data-baseweb="select"] * { color: #000000 !important; } 
    ul[data-baseweb="menu"] *, ul[role="listbox"] * { 
        color: #000000 !important; 
        background-color: #FFFFFF !important;                             /* -- dropdown options: white background */
    } 
    ul[data-baseweb="menu"] li:hover, ul[role="listbox"] li:hover { 
        background-color: #E2EFDA !important;                             /* -- hover state: sage green highlight */
        color: #2E4D23 !important; 
    } 
    ul[data-baseweb="menu"] [aria-selected="true"], ul[role="listbox"] [aria-selected="true"] { 
        background-color: #A9D18E !important;                             /* -- selected option: mint green */
        color: #FFFFFF !important; 
    } 
    div[data-testid="stDataFrame"] { background-color: #FFFFFF !important; }   /* -- tables: pure white for readability */
    .stButton>button { 
        background-color: #A9D18E !important;                             /* -- buttons: mint green to match brand */
        color: #FFFFFF !important; 
        border-radius: 10px; 
        border: none; 
        font-weight: bold; 
    } 
    </style> 
    """, unsafe_allow_html=True)

# Data readiness check
#   We verify both CSV files exist before trying to render
#   any charts. If missing, pages will show a warning
#   instead of crashing with a FileNotFoundError.
CSV_BANXICO = os.path.join(DATA_DIR, "banxico_series.csv")   # -- Banxico economic series output
CSV_TIJ_MN  = os.path.join(DATA_DIR, "tijuana_mn.csv")       # -- scraper MXN rentals output
data_ready  = os.path.exists(CSV_BANXICO) and os.path.exists(CSV_TIJ_MN)   # -- True only when both files exist

# Sidebar — Navigation
#   st.sidebar.radio renders a vertical radio button list.
#   We use emoji prefixes so each page is visually distinct
#   without adding extra icons or custom components.
st.sidebar.markdown("## ☕ Latti Coffee")
st.sidebar.write("---")

pages = [
    "☕ Home",
    "🏙️ City Comparison",
    "🧮 Calculator + Inflation",
    "💼 Minimum Wage vs Rent",
    "💱 Exchange Rate",
    "📊 General Overview",
]

page = st.sidebar.radio("", pages)   # -- selected page string drives the routing block below

# Page Router
#   Each condition maps the selected sidebar option to its
#   corresponding function in dashboard.py.
#   Keeping routing here (not inside dashboard.py) means
#   the dashboard module stays stateless and testable.
if page == "☕ Home":
    dashboard.page_home()                  # -- landing page: project summary and research questions
elif page == "🏙️ City Comparison":
    dashboard.page_comparison()            # -- violin, pie, radar and treemap charts across 4 cities
elif page == "🧮 Calculator + Inflation":
    dashboard.page_calculator()            # -- INPC-adjusted rent calculator + neighborhood bar chart
elif page == "💼 Minimum Wage vs Rent":
    dashboard.page_wages()                 # -- how many wages it takes to afford rent per city
elif page == "💱 Exchange Rate":
    dashboard.page_exchange_rate()         # -- USD/MXN history and impact on Tijuana dollar rents
elif page == "📊 General Overview":
    dashboard.page_overview()              # -- executive summary with KPI sparklines and multi-line chart