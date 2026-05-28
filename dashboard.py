# dashboard.py — Page rendering module for main.py
# Each page_*() function loads its own data, builds charts, and renders them.

import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from config import DATA_DIR

CSV_BANXICO = os.path.join(DATA_DIR, "banxico_series.csv")
CITIES      = ["tijuana", "cdmx", "monterrey", "guadalajara"]

# Display labels and brand colors per city
CITY_LABEL = {
    "tijuana":     "Tijuana",
    "cdmx":        "CDMX",
    "monterrey":   "Monterrey",
    "guadalajara": "Guadalajara",
}
COLORS = {
    "Tijuana":     "#E63946",
    "CDMX":        "#457B9D",
    "Monterrey":   "#2A9D8F",
    "Guadalajara": "#E9C46A",
}
BG = "#FDFBF7"


# Returns empty DataFrame if file not found so pages can show warnings gracefully
def load_banxico():
    if not os.path.exists(CSV_BANXICO):
        return pd.DataFrame()
    df = pd.read_csv(CSV_BANXICO)
    df["date"]  = pd.to_datetime(df["date"])
    df["value"] = pd.to_numeric(df["value"], errors="coerce")
    return df


# Loads MN and USD CSVs for all cities.
# USD listings are converted to MN using the latest Banxico rate (fallback: 17.5).
# currency="mn" includes both MN and converted USD; "usd" returns raw dollar prices.
def load_rentals(currency="mn"):
    tc_rate = 17.5
    try:
        df_b = load_banxico()
        if not df_b.empty:
            tc_vals = df_b[df_b["serie_name"] == "Exchange Rate USD/MXN"]["value"]
            if not tc_vals.empty:
                tc_rate = float(tc_vals.iloc[-1])
    except Exception:
        pass

    frames = []
    for city in CITIES:
        path_mn = os.path.join(DATA_DIR, f"{city}_mn.csv")
        if os.path.exists(path_mn):
            df = pd.read_csv(path_mn)
            df["city_label"] = CITY_LABEL[city]
            df["price"] = pd.to_numeric(df["price"], errors="coerce")
            df["price_mn"] = df["price"]
            frames.append(df)

        path_usd = os.path.join(DATA_DIR, f"{city}_usd.csv")
        if os.path.exists(path_usd):
            df_usd = pd.read_csv(path_usd)
            df_usd["city_label"] = CITY_LABEL[city]
            df_usd["price"] = pd.to_numeric(df_usd["price"], errors="coerce")
            df_usd["price_mn"] = df_usd["price"] * tc_rate
            if currency in ("mn", "all"):
                df_usd["price"] = df_usd["price_mn"]
                frames.append(df_usd)
            elif currency == "usd":
                frames.append(df_usd)

    if not frames:
        return pd.DataFrame()
    df = pd.concat(frames, ignore_index=True)
    df["price"] = pd.to_numeric(df["price"], errors="coerce")
    return df.dropna(subset=["price"])


# KPI card using raw HTML — st.metric doesn't support custom colors or shadows
def metric_card(label, value, note=None):
    note_html = f"<p style='color:#2A9D8F;font-size:12px;margin:2px 0'>{note}</p>" if note else ""
    st.markdown(f"""
<div style='background:#FFFFFF;border-radius:12px;padding:16px 20px;
box-shadow:0 2px 8px rgba(0,0,0,0.08);text-align:center;margin-bottom:8px'>
<p style='color:#888;font-size:12px;margin:0'>{label}</p>
<h2 style='color:#4B3621;margin:4px 0;font-size:22px'>{value}</h2>
{note_html}
</div>""", unsafe_allow_html=True)


# Page 0 — Landing page with KPI summary cards and research questions
def page_home():
    st.markdown("<h1 style='color:#4B3621'>☕ Latti Coffee House & Deli</h1>", unsafe_allow_html=True)
    st.markdown("<h3 style='color:#6B4226'>Gentrification Analysis — Tijuana and Metropolitan Cities</h3>",
                unsafe_allow_html=True)
    st.write("---")

    c1, c2, c3, c4 = st.columns(4)
    with c1: metric_card("Cities analyzed", "4", "TIJ · CDMX · MTY · GDL")
    with c2: metric_card("Data sources", "2", "Vivanuncios + Banxico SIE")
    with c3: metric_card("Historical period", "2000–2026", "26 years of data")
    with c4: metric_card("Economic indicators", "4 series", "TC, INPC, Wage, TIIE")

    st.write("---")
    col1, col2 = st.columns([3, 2])
    with col1:
        st.markdown("#### Research Questions")
        questions = [
            ("🏙️", "1", "Which city has the most expensive rental prices?"),
            ("🧮", "2", "How has rent changed adjusted for inflation over time?"),
            ("💼", "3", "How many minimum wages does it take to rent in each city?"),
            ("💱", "4", "How does the USD/MXN rate affect dollar-priced rents in Tijuana?"),
            ("📊", "5", "Which neighborhoods concentrate the highest rents?"),
        ]
        for emoji, num, question in questions:
            st.markdown(f"""
<div style='background:#FFFFFF;border-radius:10px;padding:12px 16px;
margin-bottom:8px;box-shadow:0 1px 4px rgba(0,0,0,0.06)'>
<span style='background:#A9D18E;color:white;border-radius:50%;
padding:2px 8px;font-weight:bold;margin-right:8px'>{num}</span>
<span style='color:#4B3621'>{emoji} {question}</span>
</div>""", unsafe_allow_html=True)
    with col2:
        st.image("https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600",
                 caption="Latti Coffee House & Deli — Tijuana, BC")


# Page 1 — Answers Q1: which city is most expensive?
# Violin + Pie + Radar + Treemap, all filtered by sidebar controls
def page_comparison():
    st.markdown("<h2 style='color:#4B3621'>🏙️ Rental Price Comparison by City</h2>", unsafe_allow_html=True)
    st.caption("Which city has the most expensive rents?")

    st.sidebar.markdown("### 🔍 Filters")
    currency = st.sidebar.radio("**Currency**", ["MN", "USD"], horizontal=True)
    df = load_rentals(currency.lower())

    if df.empty:
        st.warning("No data. Run `generate_sample_data.py` or sync first.")
        return

    city_options   = sorted(df["city_label"].unique().tolist())
    selected_cities = []
    st.sidebar.markdown("**City**")
    for c in city_options:
        if st.sidebar.checkbox(c, value=True, key=f"p1_{c}"):
            selected_cities.append(c)
    if selected_cities:
        df = df[df["city_label"].isin(selected_cities)]

    pmin, pmax  = float(df["price"].min()), float(df["price"].max())
    price_range = st.sidebar.slider("**Price range**", pmin, pmax, (pmin, pmax), format="%.0f")
    df = df[(df["price"] >= price_range[0]) & (df["price"] <= price_range[1])]

    st.write("")
    summary = df.groupby("city_label")["price"].agg(["median", "count", "min", "max"]).reset_index()
    cols = st.columns(len(summary))
    for i, row in summary.iterrows():
        if i < len(cols):
            city_color = COLORS.get(row["city_label"], "#4B3621")
            with cols[i]:
                st.markdown(f"""
<div style='background:#FFFFFF;border-radius:12px;padding:20px;
box-shadow:0 2px 8px rgba(0,0,0,0.08);text-align:center;
border-top:4px solid {city_color}'>
<p style='color:#888;font-size:14px;margin:0'>{row["city_label"]}</p>
<h2 style='color:#4B3621;margin:6px 0;font-size:28px;font-weight:700'>
{currency} {row["median"]:,.0f}
</h2>
<p style='color:#2A9D8F;font-size:13px;margin:0'>{int(row["count"])} listings</p>
</div>""", unsafe_allow_html=True)

    st.write("---")

    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### 🎻 Price Distribution by City")
        fig1 = go.Figure()
        for city in sorted(df["city_label"].unique()):
            sub = df[df["city_label"] == city]["price"]
            fig1.add_trace(go.Violin(
                y=sub, name=city,
                box_visible=True, meanline_visible=True,
                fillcolor=COLORS.get(city, "#888"),
                line_color=COLORS.get(city, "#888"),
                opacity=0.7
            ))
        fig1.update_layout(height=380, plot_bgcolor=BG, paper_bgcolor=BG,
                           showlegend=False, yaxis_title=f"Price ({currency})",
                           font=dict(color="#4B3621"))
        st.plotly_chart(fig1, use_container_width=True)

    with col2:
        st.markdown("#### 🥧 Total Rent Value Share by City")
        total_val = df.groupby("city_label")["price"].sum().reset_index()
        total_val.columns = ["City", "Total Value"]
        fig2 = px.pie(total_val, names="City", values="Total Value",
                      color="City", color_discrete_map=COLORS, hole=0.4)
        fig2.update_traces(
            texttemplate="<b>%{label}</b><br>%{percent:.1%}",
            textposition="outside",
            hovertemplate="<b>%{label}</b><br>Total: %{value:,.0f}<br>Share: %{percent:.1%}<extra></extra>"
        )
        fig2.update_layout(height=380, plot_bgcolor=BG, paper_bgcolor=BG,
                           font=dict(color="#4B3621"),
                           legend=dict(orientation="h", y=-0.1))
        st.plotly_chart(fig2, use_container_width=True)

    col3, col4 = st.columns(2)
    with col3:
        st.markdown("#### 🕸️ City Comparison Radar")
        stats = df.groupby("city_label")["price"].agg(
            Min="min", Median="median", Mean="mean", Max="max"
        ).reset_index()
        categories = ["Min", "Median", "Mean", "Max"]
        fig3 = go.Figure()
        for _, row in stats.iterrows():
            vals = [row[c] for c in categories]
            # Normalize to 0-100 so all cities share the same radar scale
            vals_norm = [v / max(stats[c].max() for c in categories) * 100 for v in vals]
            fig3.add_trace(go.Scatterpolar(
                r=vals_norm + [vals_norm[0]],
                theta=categories + [categories[0]],
                fill="toself", name=row["city_label"],
                line=dict(color=COLORS.get(row["city_label"], "#888")),
                fillcolor=COLORS.get(row["city_label"], "#888"),
                opacity=0.4
            ))
        fig3.update_layout(
            polar=dict(radialaxis=dict(visible=True, showticklabels=False)),
            height=380, paper_bgcolor=BG, font=dict(color="#4B3621"),
            legend=dict(orientation="h", y=-0.15)
        )
        st.plotly_chart(fig3, use_container_width=True)

    with col4:
        st.markdown("#### 🗺️ Neighborhoods Treemap")
        nbhd = df.groupby(["city_label", "neighborhood"])["price"].median().reset_index()
        nbhd.columns = ["City", "Neighborhood", "Median Price"]
        fig4 = px.treemap(
            nbhd, path=[px.Constant("All Cities"), "City", "Neighborhood"],
            values="Median Price", color="Median Price",
            color_continuous_scale="RdYlGn_r",
            labels={"Median Price": f"Median ({currency})"},
            custom_data=["Median Price"]
        )
        fig4.update_traces(
            hovertemplate="<b>%{label}</b><br>" + f"Median: {currency} %{{customdata[0]:,.0f}}<extra></extra>",
            root_color=BG,
            maxdepth=3
        )
        fig4.update_layout(height=380, paper_bgcolor=BG, font=dict(color="#4B3621"),
                           margin=dict(t=30, l=0, r=0, b=0))
        st.plotly_chart(fig4, use_container_width=True)

    st.write("---")
    st.markdown("#### 📅 Rent Adjusted by Inflation — How much would it cost today?")
    st.caption("Each card shows what today's median rent would have cost in that period, adjusted by INPC.")

    df_b = load_banxico()
    inpc = df_b[df_b["serie_name"] == "INPC Inflation Index"].copy() if not df_b.empty else None

    YEAR_REFS = [2000, 2005, 2010, 2015, 2020, 2026]

    inpc_now = None
    inpc_by_year = {}
    if inpc is not None and not inpc.empty:
        inpc["year"] = inpc["date"].dt.year
        inpc_now = inpc[inpc["year"] == inpc["year"].max()]["value"].mean()
        for yr in YEAR_REFS:
            val = inpc[inpc["year"] == yr]["value"].mean()
            inpc_by_year[yr] = val if not __import__("math").isnan(val) else None

    city_list = sorted(df["city_label"].unique().tolist())
    current_median_all = df.groupby("city_label")["price"].median().to_dict()

    for city in city_list:
        city_color = COLORS.get(city, "#4B3621")
        st.markdown(f"<h5 style='color:{city_color};margin-top:16px'>📍 {city}</h5>",
                    unsafe_allow_html=True)
        current_median = current_median_all.get(city, 0)
        cols_yr = st.columns(len(YEAR_REFS))
        for i, yr in enumerate(YEAR_REFS):
            inpc_yr = inpc_by_year.get(yr)
            if inpc_yr and inpc_now and inpc_now > 0:
                adjusted = current_median * (inpc_yr / inpc_now)
            else:
                adjusted = current_median
            yr_label = "Today" if yr == 2026 else str(yr)
            with cols_yr[i]:
                st.markdown(f"""
<div style='background:#FFFFFF;border-radius:10px;padding:14px;
text-align:center;box-shadow:0 1px 6px rgba(0,0,0,0.08);
margin-bottom:6px;border-top:3px solid {city_color}'>
<p style='color:#888;font-size:12px;margin:0;font-weight:600'>{yr_label}</p>
<p style='color:#4B3621;font-weight:700;font-size:18px;margin:6px 0'>
{currency} {adjusted:,.0f}
</p>
<p style='color:#aaa;font-size:10px;margin:0'>adjusted by INPC</p>
</div>""", unsafe_allow_html=True)


# Page 2 — Answers Q2 (inflation-adjusted rent) and Q5 (most expensive neighborhoods)
def page_calculator():
    st.markdown("<h2 style='color:#4B3621'>🧮 Rent Calculator + Inflation + Neighborhoods</h2>",
                unsafe_allow_html=True)
    st.caption("How much would a past rent cost today adjusted by INPC?")

    df_b = load_banxico()
    df_r = load_rentals("mn")

    if df_b.empty:
        st.warning("No Banxico data. Sync first.")
        return

    inpc = df_b[df_b["serie_name"] == "INPC Inflation Index"].copy()
    inpc["year"] = inpc["date"].dt.year

    st.sidebar.markdown("### 🔍 Filters")
    year_min   = int(inpc["year"].min())
    year_max   = int(inpc["year"].max())
    year_range = st.sidebar.slider("**INPC year range**", year_min, year_max, (2010, year_max))
    ref_year   = st.sidebar.slider("**Reference year**", year_min, year_max - 1, 2015)
    city_sel   = st.sidebar.selectbox("**City (neighborhoods)**",
                                      [CITY_LABEL[c] for c in CITIES])

    col1, col2, col3 = st.columns([1, 1, 2])
    with col1:
        current_rent = st.number_input("Your current rent (MN):", min_value=0.0,
                                       value=15000.0, step=500.0)
    inpc_ref = inpc[inpc["year"] == ref_year]["value"].mean()
    inpc_now = inpc[inpc["year"] == year_max]["value"].mean()
    if inpc_ref > 0 and inpc_now > 0:
        rent_in_ref = current_rent * (inpc_ref / inpc_now)
        change_pct  = ((current_rent - rent_in_ref) / rent_in_ref) * 100
    with col2:
        metric_card(f"Your rent in {ref_year}", f"MN {rent_in_ref:,.0f}",
                    f"+{change_pct:.1f}% due to inflation")
    with col3:
        st.info(f"Your rent of **MN {current_rent:,.0f}** in {year_max} was equivalent to "
                f"**MN {rent_in_ref:,.0f}** in {ref_year}. "
                f"Inflation increased it **{change_pct:.1f}%**.")

    st.markdown("<hr style='margin:8px 0'>", unsafe_allow_html=True)
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### INPC Evolution")
        filtered    = inpc[(inpc["year"] >= year_range[0]) & (inpc["year"] <= year_range[1])]
        inpc_annual = filtered.groupby("year")["value"].mean().reset_index()
        fig = go.Figure()
        fig.add_trace(go.Scatter(x=inpc_annual["year"], y=inpc_annual["value"],
                                 fill="tozeroy", line=dict(color="#E63946", width=2),
                                 fillcolor="rgba(230,57,70,0.15)"))
        fig.add_vline(x=ref_year, line_dash="dash", line_color="#457B9D",
                      annotation_text=f"Ref: {ref_year}")
        fig.update_layout(height=350, plot_bgcolor=BG, paper_bgcolor=BG, showlegend=False,
                          xaxis_title="Year", yaxis_title="INPC",
                          font=dict(color="#4B3621"))
        st.plotly_chart(fig, use_container_width=True)
        st.caption("📝 The INPC measures cumulative inflation in Mexico. "
                   "The dashed line marks your reference year — anything above it "
                   "shows how much prices have risen since then.")

    with col2:
        st.markdown("#### Most Expensive Neighborhoods")
        if not df_r.empty:
            sub = df_r[df_r["city_label"] == city_sel].copy()
            nbhd = (sub.groupby("neighborhood")["price"]
                    .agg(listings="count", median="median")
                    .reset_index()
                    .sort_values("median", ascending=False)
                    .head(12))
            fig2 = px.bar(nbhd, x="median", y="neighborhood", orientation="h",
                          color="median", color_continuous_scale="RdYlGn_r", text="median",
                          labels={"neighborhood": "", "median": "Median Price (MN)"})
            fig2.update_traces(
                texttemplate="MN %{text:,.0f}",
                textposition="outside",
                textfont=dict(color="#4B3621", size=11)
            )
            fig2.update_layout(height=350, showlegend=False, plot_bgcolor=BG, paper_bgcolor=BG,
                               yaxis={"categoryorder": "total ascending",
                                      "tickfont": dict(color="#4B3621", size=11)},
                               xaxis={"tickfont": dict(color="#4B3621")},
                               coloraxis_showscale=True,
                               coloraxis_colorbar=dict(title="MN", tickfont=dict(color="#4B3621")),
                               font=dict(color="#4B3621"))
            st.plotly_chart(fig2, use_container_width=True)
            st.caption(f"📝 These are the neighborhoods with the highest median rent in {city_sel}. "
                       "Red means more expensive — use the city selector on the left to compare.")

    st.write("---")
    st.markdown("#### Rent adjusted by year")
    rows = []
    for y in range(2005, year_max + 1, 5):
        inpc_y = inpc[inpc["year"] == y]["value"].mean()
        if inpc_y > 0 and inpc_now > 0:
            rows.append({"Year": y, "INPC": round(inpc_y, 1),
                         "Equivalent rent (MN)": f"{current_rent * (inpc_y / inpc_now):,.0f}"})
    if rows:
        st.dataframe(pd.DataFrame(rows), use_container_width=True)


# Page 3 — Answers Q3: how many minimum wages to pay rent?
# Uses Border Zone Minimum Wage (SF43784) — the legally applicable rate in Tijuana
def page_wages():
    st.markdown("<h2 style='color:#4B3621'>💼 Minimum Wage vs Rent</h2>", unsafe_allow_html=True)
    st.caption("How many minimum wages does it take to pay rent in each city?")

    df_b = load_banxico()
    df_r = load_rentals("mn")

    if df_b.empty or df_r.empty:
        st.warning("No data. Sync first.")
        return

    wage = df_b[df_b["serie_name"] == "Border Zone Minimum Wage"].copy()
    wage["year"] = wage["date"].dt.year
    wage_annual  = wage.groupby("year")["value"].mean().reset_index()
    wage_annual["monthly"] = (wage_annual["value"] * 30).round(2)  # daily × 30 = monthly estimate

    st.sidebar.markdown("### 🔍 Filters")
    year_min = int(wage_annual["year"].min())
    year_max = int(wage_annual["year"].max())
    ref_year = st.sidebar.slider("**Reference year**", year_min, year_max, 2024)

    ref_wage_vals = wage_annual[wage_annual["year"] == ref_year]["monthly"].values
    ref_wage = ref_wage_vals[0] if len(ref_wage_vals) > 0 else 0

    medians = df_r.groupby("city_label")["price"].median().reset_index()
    medians.columns = ["City", "Rent"]
    medians["Wages"] = (medians["Rent"] / ref_wage).round(1) if ref_wage > 0 else 0

    st.write("")
    cols = st.columns(len(medians) + 1)
    with cols[0]:
        metric_card(f"Monthly Wage {ref_year}", f"MN {ref_wage:,.0f}", "Border zone")
    for i, row in medians.iterrows():
        if i + 1 < len(cols):
            with cols[i + 1]:
                metric_card(f"Wages for {row['City']}", f"{row['Wages']}x",
                            f"MN {row['Rent']:,.0f} median")

    st.write("---")
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### Border Zone Minimum Wage Evolution")
        fig1 = go.Figure()
        fig1.add_trace(go.Scatter(x=wage_annual["year"], y=wage_annual["monthly"],
                                  fill="tozeroy", line=dict(color="#2A9D8F", width=2),
                                  fillcolor="rgba(42,157,143,0.2)"))
        fig1.add_vline(x=ref_year, line_dash="dash", line_color="#E63946",
                       annotation_text=f"{ref_year}: MN {ref_wage:,.0f}")
        fig1.update_layout(height=360, plot_bgcolor=BG, paper_bgcolor=BG, showlegend=False,
                           xaxis_title="Year", yaxis_title="Monthly Wage (MN)",
                           font=dict(color="#4B3621"),
                           xaxis=dict(tickfont=dict(color="#4B3621")),
                           yaxis=dict(tickfont=dict(color="#4B3621")))
        st.plotly_chart(fig1, use_container_width=True)
        st.caption(f"📝 The border zone minimum wage grew significantly after 2019 "
                   f"with the Free Zone policy. In {ref_year} it reached MN {ref_wage:,.0f}/month.")

    with col2:
        st.markdown("#### Wages Needed to Rent by City")
        fig2 = px.bar(medians.sort_values("Wages", ascending=False),
                      x="City", y="Wages", color="City", color_discrete_map=COLORS,
                      text="Wages", labels={"Wages": f"Minimum wages ({ref_year})"})
        fig2.update_traces(texttemplate="%{text}x", textposition="outside",
                           textfont=dict(color="#4B3621"))
        fig2.update_layout(showlegend=False, height=360, plot_bgcolor=BG, paper_bgcolor=BG,
                           font=dict(color="#4B3621"),
                           xaxis=dict(tickfont=dict(color="#4B3621")),
                           yaxis=dict(tickfont=dict(color="#4B3621")))
        st.plotly_chart(fig2, use_container_width=True)
        st.caption("📝 A family needs multiple minimum wages just to afford a commercial rental. "
                   "This gap is one of the key drivers of gentrification.")

    st.write("---")
    col3, col4 = st.columns(2)
    with col3:
        st.markdown("#### Median Rent vs Monthly Wage")
        fig3 = go.Figure()
        fig3.add_trace(go.Bar(name="Median Rent", x=medians["City"], y=medians["Rent"],
                              marker_color=[COLORS.get(c, "#888") for c in medians["City"]]))
        fig3.add_trace(go.Scatter(name=f"Wage {ref_year}", x=medians["City"],
                                  y=[ref_wage] * len(medians), mode="lines+markers",
                                  line=dict(color="#E63946", width=3, dash="dash")))
        fig3.update_layout(height=360, plot_bgcolor=BG, paper_bgcolor=BG,
                           yaxis_title="MN", font=dict(color="#4B3621"),
                           xaxis=dict(tickfont=dict(color="#4B3621")),
                           yaxis=dict(tickfont=dict(color="#4B3621")))
        st.plotly_chart(fig3, use_container_width=True)
        st.caption("📝 The red line is the monthly minimum wage. Every bar above it "
                   "means rent exceeds what a minimum wage worker earns in a month.")

    with col4:
        st.markdown("#### Rent as % of Monthly Wage")
        medians["pct"] = (medians["Rent"] / ref_wage * 100).round(1) if ref_wage > 0 else 0
        fig4 = px.pie(medians, names="City", values="Rent",
                      color="City", color_discrete_map=COLORS, hole=0.45)
        fig4.update_traces(
            texttemplate="<b>%{label}</b><br>%{percent:.1%}",
            hovertemplate="<b>%{label}</b><br>Median Rent: MN %{value:,.0f}<extra></extra>"
        )
        fig4.update_layout(height=360, plot_bgcolor=BG, paper_bgcolor=BG,
                           font=dict(color="#4B3621"),
                           legend=dict(font=dict(color="#4B3621")))
        st.plotly_chart(fig4, use_container_width=True)
        st.caption("📝 Share of median rent by city — shows which city concentrates "
                   "the highest rental costs relative to the others.")


# Page 4 — Answers Q4: how does the exchange rate affect dollar rents in Tijuana?
# Tijuana landlords price in USD to hedge against peso devaluation,
# which raises real costs for residents who earn in MXN.
def page_exchange_rate():
    st.markdown("<h2 style='color:#4B3621'>💱 USD/MXN Exchange Rate</h2>", unsafe_allow_html=True)
    st.caption("How has the exchange rate changed and what does it mean for dollar rents in Tijuana?")

    df_b     = load_banxico()
    df_r_usd = load_rentals("usd")
    df_r_mn  = load_rentals("mn")

    if df_b.empty:
        st.warning("No data. Sync first.")
        return

    tc = df_b[df_b["serie_name"] == "Exchange Rate USD/MXN"].copy()
    tc["year"] = tc["date"].dt.year

    st.sidebar.markdown("### 🔍 Filters")
    year_min   = int(tc["year"].min())
    year_max   = int(tc["year"].max())
    year_range = st.sidebar.slider("**Year range**", year_min, year_max, (2010, year_max))
    ref_year   = st.sidebar.slider("**Reference year**", year_min, year_max, 2018)
    rent_mn    = st.sidebar.number_input("**Your rent (MN):**", min_value=0.0,
                                         value=15000.0, step=500.0)

    tc_filtered = tc[(tc["year"] >= year_range[0]) & (tc["year"] <= year_range[1])]
    tc_ref = tc[tc["year"] == ref_year]["value"].mean()
    tc_now = tc[tc["year"] == year_max]["value"].mean()
    var_pct      = ((tc_now - tc_ref) / tc_ref * 100) if tc_ref > 0 else 0
    rent_usd_now = rent_mn / tc_now if tc_now > 0 else 0
    rent_usd_ref = rent_mn / tc_ref if tc_ref > 0 else 0

    c1, c2, c3, c4 = st.columns(4)
    with c1: metric_card(f"Avg rate {ref_year}", f"${tc_ref:.2f}", "MXN per USD")
    with c2: metric_card(f"Avg rate {year_max}", f"${tc_now:.2f}", "MXN per USD")
    with c3: metric_card("Variation", f"+{var_pct:.1f}%", f"{ref_year} → {year_max}")
    with c4: metric_card(f"Rent in USD ({year_max})", f"USD {rent_usd_now:,.0f}",
                         f"vs USD {rent_usd_ref:,.0f} in {ref_year}")

    st.write("---")
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### Historical Exchange Rate")
        tc_annual = tc_filtered.groupby("year")["value"].mean().reset_index()
        fig1 = go.Figure()
        fig1.add_trace(go.Scatter(x=tc_annual["year"], y=tc_annual["value"],
                                  fill="tozeroy", line=dict(color="#457B9D", width=2),
                                  fillcolor="rgba(69,123,157,0.2)"))
        fig1.add_vline(x=ref_year, line_dash="dash", line_color="#E63946",
                       annotation_text=f"{ref_year}: ${tc_ref:.2f}")
        fig1.update_layout(height=360, plot_bgcolor=BG, paper_bgcolor=BG, showlegend=False,
                           xaxis_title="Year", yaxis_title="MXN per USD")
        st.plotly_chart(fig1, use_container_width=True)
        st.caption(f"📝 The USD/MXN rate went from ~$9 in 2000 to ${tc_now:.2f} today — "
                   f"a +{var_pct:.0f}% devaluation that makes dollar-priced rents "
                   f"significantly more expensive in MXN terms.")

    with col2:
        st.markdown("#### Median USD Rent by City")
        if not df_r_usd.empty:
            med_usd = df_r_usd.groupby("city_label")["price"].median().reset_index()
            med_usd.columns = ["City", "USD Median"]
            fig2 = px.bar(med_usd.sort_values("USD Median", ascending=False),
                          x="City", y="USD Median", color="City",
                          color_discrete_map=COLORS, text="USD Median")
            fig2.update_traces(texttemplate="USD %{text:,.0f}", textposition="outside")
            fig2.update_layout(showlegend=False, height=360, plot_bgcolor=BG, paper_bgcolor=BG)
            st.plotly_chart(fig2, use_container_width=True)
            st.caption("📝 Tijuana leads in USD-priced rentals due to its border location. "
                       "Landlords price in dollars to protect against peso devaluation, "
                       "directly impacting local tenants who earn in MXN.")
        else:
            st.info("No USD listings available.")

    st.write("---")
    col3, col4 = st.columns(2)
    with col3:
        st.markdown("#### MN Rent in USD — Tijuana Neighborhoods")
        if not df_r_mn.empty:
            tij = df_r_mn[df_r_mn["city_label"] == "Tijuana"].copy()
            tij["usd_now"] = tij["price"] / tc_now
            tij["usd_ref"] = tij["price"] / tc_ref
            tij_grp = tij.groupby("neighborhood")[["usd_now", "usd_ref"]].median().reset_index()
            tij_grp = tij_grp.sort_values("usd_now", ascending=False).head(10)
            fig3 = go.Figure()
            fig3.add_trace(go.Bar(name=f"USD {year_max}", x=tij_grp["neighborhood"],
                                  y=tij_grp["usd_now"], marker_color="#457B9D"))
            fig3.add_trace(go.Bar(name=f"USD {ref_year}", x=tij_grp["neighborhood"],
                                  y=tij_grp["usd_ref"], marker_color="#E9C46A"))
            fig3.update_layout(barmode="group", height=360, plot_bgcolor=BG, paper_bgcolor=BG,
                               xaxis_tickangle=-30)
            st.plotly_chart(fig3, use_container_width=True)

    with col4:
        st.markdown("#### 💰 USD Rent Ranges in Tijuana")
        if not df_r_usd.empty:
            tij_usd = df_r_usd[df_r_usd["city_label"] == "Tijuana"].copy()
            bins   = [0, 500, 1000, 2000, 3500, 5000, 10000, 50000]
            labels = ["<$500", "$500-1k", "$1k-2k", "$2k-3.5k", "$3.5k-5k", "$5k-10k", ">$10k"]
            tij_usd["range"] = pd.cut(tij_usd["price"], bins=bins, labels=labels)
            range_count = tij_usd["range"].value_counts().sort_index().reset_index()
            range_count.columns = ["Range", "Listings"]
            colors = ["#2A9D8F","#457B9D","#E9C46A","#F4A261","#E76F51","#E63946","#9B2226"]
            fig4 = go.Figure(go.Bar(
                x=range_count["Range"],
                y=range_count["Listings"],
                marker_color=colors[:len(range_count)],
                text=range_count["Listings"],
                textposition="outside"
            ))
            fig4.update_layout(
                height=360, plot_bgcolor=BG, paper_bgcolor=BG,
                font=dict(color="#4B3621"),
                xaxis_title="Price Range (USD)",
                yaxis_title="Listings",
                yaxis_range=[0, 120],
                showlegend=False,
                bargap=0.1
            )
            st.plotly_chart(fig4, use_container_width=True)
            st.caption("📝 Most USD listings in Tijuana concentrate between $1k–$3.5k/month, "
                       "reflecting the near-shore commercial demand from the US border.")


# Page 5 — Executive summary with dark navy theme and sparkline KPI cards
# Neon accent colors on dark blue create strong contrast for presentation contexts
def page_overview():
    st.markdown("""
<style>
[data-testid="stAppViewContainer"] > .main .block-container {
background: linear-gradient(160deg, #0F2537 0%, #1B3A4B 60%, #0D1F2D 100%);
border-radius: 16px; padding: 24px;
}
</style>""", unsafe_allow_html=True)

    st.markdown("<h2 style='color:#00D4FF'>📊 General Overview — Gentrification Tijuana</h2>",
                unsafe_allow_html=True)
    st.markdown("<p style='color:#A8C8E0'>Executive summary of all key indicators</p>",
                unsafe_allow_html=True)

    df_b = load_banxico()
    df_r = load_rentals("mn")

    if df_b.empty:
        st.warning("No data. Sync first.")
        return

    DARK   = "#0F2537"
    CARD   = "#162D3F"
    CYAN   = "#00D4FF"
    GREEN  = "#39FF14"
    ORANGE = "#FF6B35"
    PINK   = "#FF3CAC"
    YELLOW = "#FFD166"
    TEXT   = "#E8F4F8"
    SUBTEXT = "#7FB3C8"

    tc_df   = df_b[df_b["serie_name"] == "Exchange Rate USD/MXN"].copy()
    inpc_df = df_b[df_b["serie_name"] == "INPC Inflation Index"].copy()
    sal_df  = df_b[df_b["serie_name"] == "Border Zone Minimum Wage"].copy()
    tiie_df = df_b[df_b["serie_name"] == "TIIE Interest Rate"].copy()

    tc_df["year"]   = tc_df["date"].dt.year
    inpc_df["year"] = inpc_df["date"].dt.year
    sal_df["year"]  = sal_df["date"].dt.year
    tiie_df["year"] = tiie_df["date"].dt.year

    tc_val   = tc_df["value"].iloc[-1]
    inpc_val = inpc_df["value"].iloc[-1]
    sal_val  = sal_df["value"].iloc[-1] * 30
    tiie_val = tiie_df["value"].iloc[-1]
    r_tij    = df_r[df_r["city_label"] == "Tijuana"]["price"].median() if not df_r.empty else 0

    kpis = [
        ("💱 Exchange Rate", f"${tc_val:.2f}", "MXN/USD", tc_df.groupby("year")["value"].mean(), CYAN),
        ("📈 INPC Index",    f"{inpc_val:.1f}", "Base 2018=100", inpc_df.groupby("year")["value"].mean(), PINK),
        ("💼 Monthly Wage",  f"MN {sal_val:,.0f}", "Border zone", sal_df.groupby("year")["value"].apply(lambda x: x.mean()*30), GREEN),
        ("🏠 Rent Tijuana",  f"MN {r_tij:,.0f}", "Median commercial", sal_df.groupby("year")["value"].mean().apply(lambda x: r_tij), ORANGE),
        ("📉 TIIE Rate",     f"{tiie_val:.2f}%", "Interest rate", tiie_df.groupby("year")["value"].mean(), YELLOW),
    ]

    cols = st.columns(5)
    for i, (label, value, note, spark_data, color) in enumerate(kpis):
        with cols[i]:
            if spark_data is not None and len(spark_data) > 2:
                spark_df = spark_data.reset_index()
                spark_df.columns = ["year", "val"]
                # Convert hex to rgba for the sparkline fill
                fig_spark = go.Figure(go.Scatter(
                    x=spark_df["year"], y=spark_df["val"],
                    mode="lines", line=dict(color=color, width=2),
                    fill="tozeroy", fillcolor=f"rgba({int(color[1:3],16)},{int(color[3:5],16)},{int(color[5:7],16)},0.15)"
                ))
                fig_spark.update_layout(
                    height=60, margin=dict(l=0, r=0, t=0, b=0),
                    plot_bgcolor="rgba(0,0,0,0)", paper_bgcolor="rgba(0,0,0,0)",
                    xaxis=dict(visible=False), yaxis=dict(visible=False),
                    showlegend=False
                )
                st.plotly_chart(fig_spark, use_container_width=True, config={"displayModeBar": False})
            st.markdown(f"""
<div style='background:{CARD};border-radius:10px;padding:14px 16px;
border-left:4px solid {color};margin-top:-10px'>
<span style='display:block;color:#FFFFFF !important;font-size:12px;margin:0;opacity:0.8'>{label}</span>
<span style='display:block;color:{color} !important;margin:4px 0;font-size:22px;font-weight:700;font-family:sans-serif'>{value}</span>
<span style='display:block;color:#DDDDDD !important;font-size:11px;margin:0;opacity:0.9'>{note}</span>
</div>""", unsafe_allow_html=True)

    st.write("")
    st.markdown("<hr style='border-color:#1E3F55'>", unsafe_allow_html=True)

    col1, col2 = st.columns([3, 2])
    with col1:
        st.markdown(f"<h4 style='color:{TEXT}'>📈 Economic Indicators Evolution</h4>",
                    unsafe_allow_html=True)
        tc_a   = tc_df.groupby("year")["value"].mean().reset_index()
        inpc_a = inpc_df.groupby("year")["value"].mean().reset_index()
        tiie_a = tiie_df.groupby("year")["value"].mean().reset_index()

        fig_multi = go.Figure()
        fig_multi.add_trace(go.Scatter(x=tc_a["year"], y=tc_a["value"],
                                       name="Exchange Rate", line=dict(color=CYAN, width=2.5),
                                       fill="tozeroy", fillcolor="rgba(0,212,255,0.08)"))
        fig_multi.add_trace(go.Scatter(x=inpc_a["year"], y=inpc_a["value"],
                                       name="INPC", line=dict(color=PINK, width=2.5)))
        fig_multi.add_trace(go.Scatter(x=tiie_a["year"], y=tiie_a["value"],
                                       name="TIIE %", line=dict(color=YELLOW, width=2, dash="dot")))
        fig_multi.update_layout(
            height=320, plot_bgcolor=DARK, paper_bgcolor=CARD,
            font=dict(color=TEXT), legend=dict(orientation="h", y=-0.2),
            xaxis=dict(gridcolor="#1E3F55"), yaxis=dict(gridcolor="#1E3F55"),
            margin=dict(t=10, b=10)
        )
        st.plotly_chart(fig_multi, use_container_width=True)

    with col2:
        st.markdown(f"<h4 style='color:{TEXT}'>🥧 Median Rent Share by City</h4>",
                    unsafe_allow_html=True)
        if not df_r.empty:
            med_val = df_r.groupby("city_label")["price"].median().reset_index()
            med_val.columns = ["City", "Median"]
            fig_pie = px.pie(med_val, names="City", values="Median",
                             color="City", color_discrete_map=COLORS, hole=0.45)
            fig_pie.update_traces(
                texttemplate="<b>%{label}</b><br>%{percent:.1%}",
                textfont=dict(color=TEXT)
            )
            fig_pie.update_layout(
                height=320, paper_bgcolor=CARD,
                font=dict(color=TEXT),
                legend=dict(orientation="h", y=-0.15, font=dict(color=TEXT)),
                margin=dict(t=10, b=10)
            )
            st.plotly_chart(fig_pie, use_container_width=True)

    st.markdown("<hr style='border-color:#1E3F55'>", unsafe_allow_html=True)

    col3, col4, col5 = st.columns(3)

    with col3:
        st.markdown(f"<h4 style='color:{TEXT}'>🏙️ Median Rent by City</h4>",
                    unsafe_allow_html=True)
        if not df_r.empty:
            med = df_r.groupby("city_label")["price"].median().reset_index()
            med.columns = ["City", "Median"]
            med = med.sort_values("Median", ascending=False)
            fig3 = px.bar(med, x="City", y="Median", color="City",
                          color_discrete_map=COLORS, text="Median")
            fig3.update_traces(texttemplate="MN %{text:,.0f}", textposition="outside",
                               textfont=dict(color=TEXT))
            fig3.update_layout(height=300, plot_bgcolor=DARK, paper_bgcolor=CARD,
                               showlegend=False, font=dict(color=TEXT),
                               xaxis=dict(gridcolor="#1E3F55"),
                               yaxis=dict(gridcolor="#1E3F55"),
                               margin=dict(t=10, b=10))
            st.plotly_chart(fig3, use_container_width=True)
            st.markdown(f"<p style='color:{SUBTEXT};font-size:12px'>📝 Tijuana competes with CDMX driven by near-shore demand.</p>",
                        unsafe_allow_html=True)

    with col4:
        st.markdown(f"<h4 style='color:{TEXT}'>💼 Wage vs Estimated Rent Evolution</h4>",
                    unsafe_allow_html=True)
        sal_a = sal_df.groupby("year")["value"].mean().reset_index()
        sal_a["monthly"] = sal_a["value"] * 30

        inpc_a2 = inpc_df.groupby("year")["value"].mean().reset_index()
        inpc_a2.columns = ["year", "inpc_val"]
        inpc_now2 = inpc_a2["inpc_val"].iloc[-1] if not inpc_a2.empty else 100
        sal_merged = sal_a.merge(inpc_a2, on="year", how="left")
        sal_merged["est_rent"] = r_tij * (sal_merged["inpc_val"] / inpc_now2)

        fig4 = go.Figure()
        fig4.add_trace(go.Scatter(
            x=sal_merged["year"], y=sal_merged["monthly"],
            name="Monthly Wage", mode="lines+markers",
            line=dict(color=GREEN, width=2.5),
            fill="tozeroy", fillcolor="rgba(57,255,20,0.1)"
        ))
        fig4.add_trace(go.Scatter(
            x=sal_merged["year"], y=sal_merged["est_rent"],
            name="Est. Rent Tijuana", mode="lines+markers",
            line=dict(color=ORANGE, width=2.5, dash="dot"),
            fill="tozeroy", fillcolor="rgba(255,107,53,0.1)"
        ))
        fig4.update_layout(
            height=300, plot_bgcolor=DARK, paper_bgcolor=CARD,
            font=dict(color=TEXT),
            legend=dict(orientation="h", y=-0.25, font=dict(color=TEXT)),
            xaxis=dict(gridcolor="#1E3F55"),
            yaxis=dict(gridcolor="#1E3F55", title="MN"),
            margin=dict(t=10, b=10)
        )
        st.plotly_chart(fig4, use_container_width=True)
        wage_2000 = sal_merged["monthly"].iloc[0] if not sal_merged.empty else 1
        wage_now  = sal_merged["monthly"].iloc[-1] if not sal_merged.empty else 1
        rent_2000 = sal_merged["est_rent"].iloc[0] if not sal_merged.empty else 1
        rent_now  = sal_merged["est_rent"].iloc[-1] if not sal_merged.empty else 1
        wage_growth = ((wage_now - wage_2000) / wage_2000 * 100) if wage_2000 > 0 else 0
        rent_growth = ((rent_now - rent_2000) / rent_2000 * 100) if rent_2000 > 0 else 0
        st.caption(
            f"📝 While the estimated rent grew +{rent_growth:.0f}% since 2000, "
            f"the minimum wage only grew +{wage_growth:.0f}% — "
            f"a gap that drives gentrification in Tijuana."
        )

    with col5:
        st.markdown(f"<h4 style='color:{TEXT}'>📉 INPC Inflation Growth</h4>",
                    unsafe_allow_html=True)
        inpc_a = inpc_df.groupby("year")["value"].mean().reset_index()
        fig5 = go.Figure(go.Scatter(
            x=inpc_a["year"], y=inpc_a["value"],
            fill="tozeroy", line=dict(color=PINK, width=2.5),
            fillcolor="rgba(255,60,172,0.15)"
        ))
        fig5.update_layout(height=300, plot_bgcolor=DARK, paper_bgcolor=CARD,
                           font=dict(color=TEXT), showlegend=False,
                           xaxis=dict(gridcolor="#1E3F55"),
                           yaxis=dict(gridcolor="#1E3F55"),
                           margin=dict(t=10, b=10))
        st.plotly_chart(fig5, use_container_width=True)
        st.markdown(f"<p style='color:{SUBTEXT};font-size:12px'>📝 Accumulated inflation since 2000 exceeds 300%.</p>",
                    unsafe_allow_html=True)