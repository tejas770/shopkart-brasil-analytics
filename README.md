# ShopKart Brasil — Delivery & Customer Experience Analytics

An end-to-end Data Analyst project built on the Olist Brazilian e-commerce
dataset, framed around a fictional multi-seller marketplace, **ShopKart
Brasil**. The project follows a full pipeline — business problem, data
modeling, ETL, PostgreSQL, SQL analysis, statistics, Python EDA, and a 5-page
Power BI dashboard — to diagnose and explain a real operational problem:
**rising delivery delays and their downstream effect on customer
satisfaction.**

## Business Problem

ShopKart's Operations and Customer Support teams independently noticed two
things worsening in early 2018: delivery delays, and customer complaints
(low review scores). This project investigates whether these are related,
finds the root cause, and quantifies the business impact.

**Result:** They are the same problem. A shrinking "delivery-promise buffer"
(the safety margin between the promised delivery date and the actual
delivery date) is the strongest single driver of late-delivery spikes, and
late deliveries carry a review score roughly half that of on-time orders —
a pattern that holds in every state examined.

See [`documentation/executive_summary.md`](documentation/executive_summary.md)
for the full narrative and recommendations.

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
— 9 CSV files covering ~99,000 orders (Sep 2016 - Oct 2018): orders, order
items, payments, reviews, products, customers, sellers, geolocation, and a
category-name translation table.

## Architecture

```
Raw CSVs (Kaggle)
      │
      ▼
Python Extraction & Cleaning  (python/extraction, python/cleaning)
      │
      ▼
Parquet (data/processed) ──▶ PostgreSQL (schema: olist)
                                    │
                     ┌──────────────┼──────────────┐
                     ▼              ▼              ▼
              SQL Analysis   Python EDA      Power BI Dashboard
              (sql/business_  (python/eda/    (powerbi/
               queries/)       charts.py)      shopkart_dashboard.pbix)
                     │              │              │
                     └──────────────┴──────────────┘
                                    ▼
                     Business Insights & Recommendations
                     (documentation/executive_summary.md)
```

## Data Model

A star schema, designed on top of the raw Olist tables:

- **Fact table:** `order_items` (grain: one row = one item within one order)
- **Dimensions:** `customers`, `sellers`, `products` (+ `category_translation`)
- **Degenerate dimension:** `order_status` (kept as a column on `orders`
  rather than a separate table — too simple to justify a dimension)
- A dedicated view, **`olist.v_delivered_orders`**, centralizes the
  "delivered order" and "is late" definitions so every downstream query and
  dashboard measure uses the same logic. See
  [`sql/views/v_delivered_orders.sql`](sql/views/v_delivered_orders.sql).

Snowflaking and slowly-changing dimensions (SCD Type 2) were considered but
not implemented — the dataset is a static historical snapshot, so the added
complexity would not pay for itself in a fresher-level project. See
`documentation/kpi_dictionary.md` for full KPI definitions and reasoning.

## Tools Used

| Tool | Purpose |
|---|---|
| Python (pandas, SQLAlchemy) | Extraction, cleaning, ETL pipeline |
| PostgreSQL | Data warehouse, all business-question SQL |
| Python (matplotlib, seaborn, scipy) | EDA charts, hypothesis testing, confidence intervals |
| Power BI | 5-page interactive dashboard, DAX measures |

## ETL Process

`python/etl_pipeline.py` runs end-to-end: extract 9 CSVs → validate row
counts → clean (parse dates, dedupe reviews by latest timestamp, fill
missing product categories, derive `delivery_days`/`is_late`) → save to
Parquet → load into PostgreSQL in FK-safe order (`TRUNCATE` then reload, so
the pipeline is safely re-runnable).

## SQL Analysis

12 SQL files in `sql/business_queries/`, from baseline KPIs through
window-function-heavy monthly trends, seller/category grain-aware
aggregation, and two full business-case investigations. Highlights:

- **Q2:** Late-rate definition sensitivity — a timestamp-level vs date-level
  comparison changes the reported rate from 8.11% to 6.77%.
- **Q5:** Confirms the delay → low-review-score relationship holds *within*
  every state, ruling out state-mix as a confounder.
- **Q7-Q8:** Decomposes delivery time into seller-handling vs carrier-transit,
  and discovers the promise-buffer relationship (r = -0.61, p = 0.004) —
  the project's central finding.
- **Case #1:** A CFO's claimed 20% GMV decline turned out to be a false
  premise (GMV had actually *increased* 15.2%) — a lesson in verifying
  stakeholder claims before diagnosing a root cause.
- **Case #2:** Confirmed complaint-rate increase, decomposed into 68.5%
  mix-shift (more orders becoming late) vs 31.5% within-group effect.

## Python Analysis (EDA & Statistics)

`python/eda/charts.py` reproduces 3 key visuals directly from PostgreSQL via
`pandas.read_sql`: the monthly late-rate trend, the late-vs-on-time review
score distribution, and the buffer-vs-late-rate scatter with a fitted
regression line. Statistical tests applied:

- Pearson correlation + significance test (buffer vs late rate)
- 95% confidence intervals on state-level late rates (showing several states'
  apparent ranking differences are not statistically distinguishable)
- Two-proportion z-test (H1 2017 vs H1 2018 complaint rate)

## Power BI Dashboard

5 pages, built on a live PostgreSQL connection with a dedicated Date table
for time intelligence:

1. **Executive Overview** — KPI cards, GMV/late-rate trend, top late states, order-status breakdown
2. **Customer Experience & Retention** — repeat-purchase rate (3.12%, using `customer_unique_id`, not `customer_id`), order-count distribution
3. **Product/Category Analysis** — revenue ranking, category late rates, seller late-rate vs GMV scatter
4. **Regional Analysis** — bubble map (via geolocation lat/lng) and a state-wise summary table
5. **Operational Analysis** — seller-handling vs carrier-transit trend, buffer-vs-late-rate chart

See `screenshots/` for page previews.

## KPI Dictionary (summary)

| KPI | Value | Definition |
|---|---|---|
| Delivered Orders | 96,470 | `order_status='delivered'` AND delivery date present |
| GMV (proxy) | R$15.42M | `SUM(price + freight_value)`, delivered only |
| AOV | R$159.83 | GMV ÷ delivered orders |
| Late Delivery Rate | 6.77% | `delivered_date::date > estimated_date::date` |
| Avg / Median Delivery Time | 12.56 / 10.22 days | Purchase → customer delivery |
| Review Score (on-time vs late) | 4.29 vs 2.27 | Holds within every state (gap 1.63-2.62) |
| Promise Buffer | r = -0.61 with late rate | Estimated date − delivered date |
| Repeat Purchase Rate | 3.12% | Based on `customer_unique_id`, not per-order `customer_id` |

Full definitions, business meaning, and caveats: `documentation/kpi_dictionary.md`.

## Key Insights & Recommendations

1. Delivery delays more than doubled (3.87% → 8.63%) between H1 2017 and H1
   2018, and are best predicted by a shrinking delivery-promise buffer, not
   by seller handling time (which stayed flat at ~3 days) or product weight
   (weak 0.21 correlation).
2. Late orders receive dramatically lower reviews (2.27 vs 4.29 / 5), and
   this drove a rise in the overall low-rating rate (11.13% → 14.54%) — a
   downstream symptom of delivery performance, not a separate quality issue.
3. The worst seller-level and state-level late rates are concentrated in
   small-volume sellers and Northeast Brazil states — the company's largest
   sellers stay within 5-10.5%.

**Recommendation:** maintain at least an 8-10 day delivery-promise buffer
during high-demand periods, plan carrier capacity ahead of demand spikes, and
treat delivery reliability as a shared Operations/Customer-Support priority
rather than two separate problems.

## Business Impact

If the current trend continues unaddressed, it puts customer retention at
risk — the platform's repeat-purchase rate is already low (3.12%). Targeting
the delivery-promise buffer is expected to bring the late rate back toward
4-5% (achieved in calmer months) and the low-rating rate back toward 11-12%.

## Project Structure

```
shopkart-delivery-analytics/
├── data/                    # raw/processed (gitignored)
├── python/
│   ├── extraction/          # load_data.py
│   ├── cleaning/            # clean.py
│   ├── eda/                 # charts.py
│   └── etl_pipeline.py
├── sql/
│   ├── schema/              # create_tables.sql
│   ├── views/                # v_delivered_orders.sql
│   └── business_queries/    # q1-q10 + 2 business cases
├── powerbi/                 # shopkart_dashboard.pbix
├── documentation/           # kpi_dictionary, executive_summary, data_quality_report
├── screenshots/             # dashboard page previews
├── requirements.txt
└── README.md
```

## How to Reproduce

1. Download the [Olist dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) into `data/raw/`.
2. `pip install -r requirements.txt`
3. Run `sql/schema/create_tables.sql` on a fresh PostgreSQL database.
4. Update the connection string in `python/etl_pipeline.py`, then run it:
   `python python/etl_pipeline.py`
5. Run `sql/views/v_delivered_orders.sql`, then any file in
   `sql/business_queries/`.
6. Run `python python/eda/charts.py` for the EDA charts (saved to `reports/`).
7. Open `powerbi/shopkart_dashboard.pbix` in Power BI Desktop and point the
   PostgreSQL connector at your local database.

## Future Improvements

- Text-analysis on `review_comment_message` to identify complaint reasons
  beyond the review-score proxy.
- Incremental (rather than full) load, if this were a live, daily-refreshing
  system — see `documentation/` for the watermark-based approach considered.
- A logistic regression / proper causal design to move beyond the
  association-level findings in this project (explicitly noted as a
  limitation — see `documentation/executive_summary.md`).
