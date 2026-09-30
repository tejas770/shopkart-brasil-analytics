# Data Quality Report — Olist / ShopKart Brasil Dataset

Findings from profiling the 9 raw Olist tables before cleaning (Steps 8-9).

## Row Counts (raw)

| Table | Rows |
|---|---|
| customers | 99,441 |
| geolocation | 1,000,163 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| orders | 99,441 |
| products | 32,951 |
| sellers | 3,095 |
| category_translation | 71 |

`customers` = `orders` (99,441 each) confirms `customer_id` is per-order unique in
this dataset, not a real customer identifier — the real customer is
`customer_unique_id`.

## Issues Found and How They Were Handled

| # | Table | Issue | Decision | Reason |
|---|---|---|---|---|
| 1 | orders | `order_approved_at` missing (160), `order_delivered_carrier_date` missing (1,783), `order_delivered_customer_date` missing (2,965) | Keep as NULL, do not impute | These are real events that never happened (order never approved/shipped/delivered), not data errors |
| 2 | orders | Delivery KPIs only meaningful for delivered orders | Filter `order_status = 'delivered'` for all delivery-time analysis | Non-delivered orders have no real "delivery time" |
| 3 | order_reviews | 551 duplicate `order_id` rows (some orders have 2+ reviews) | Deduplicate — keep the review with the latest `review_answer_timestamp` | The final/most-relevant review should count once per order |
| 4 | order_reviews | 768 orders have no review at all | Do not drop — use LEFT JOIN when joining reviews to orders | INNER JOIN would silently remove these orders from revenue/delivery analysis |
| 5 | order_reviews | `review_comment_title`/`review_comment_message` mostly missing (88%/59%) | Keep as-is; text analysis excluded from project scope | These are optional fields customers are not required to fill |
| 6 | products | 610 rows (1.85%) missing category name and catalog metadata (same 610 rows across all 4 affected columns — verified, not coincidence) | Fill `product_category_name` with `'unknown'`; keep other fields, do not drop rows | Dropping would lose valid order/revenue data linked to these products just because catalog metadata was incomplete |
| 7 | products | 2 rows missing weight/dimensions | Median-fill by category (median chosen over mean — more robust to outliers) | Negligible impact (0.006% of rows) |
| 8 | orders | 8 orders marked `delivered` but `order_delivered_customer_date` is NULL — a data inconsistency | Excluded from delivery-time KPIs (captured by `v_delivered_orders` view's `IS NOT NULL` filter) | Cannot compute a delivery duration without a delivery date |
| 9 | orders | 8 orders showed an anomalous single delivery date (2017-09-19) despite purchase dates spanning Feb-Mar 2017 (up to 209 days "late") | Kept in the dataset; flagged as a likely one-time backlog/system event rather than a typical delay; excluded from "typical delay" root-cause discussion | Pattern (same exact date across unrelated purchases) strongly suggests a systemic event, not independent extreme delays |
| 10 | orders | ~189 orders (0.2%) show impossible negative durations: 165 with carrier-handover date before purchase, 23 with customer-delivery date before carrier handover, 1 with carrier date null among delivered orders | Excluded from seller/carrier day averages only (Q7); late-rate KPI stays on the full set | A small, likely data-logging inconsistency; excluding it only from duration averages keeps the late-rate KPI reconciled across all queries |
| 11 | orders | 775 delivered-adjacent orders have no rows in `order_items` at all (603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped) | Excluded automatically by INNER JOIN to `order_items` for revenue queries; explicitly checked before assuming delivered-orders counts reconcile | Orders with no items generated no revenue; the 1 shipped / 2 invoiced cases are a minor logged anomaly worth noting |

## Known Dataset Limitations (carried into analysis assumptions)

- **GMV is a proxy for revenue.** It is `SUM(price + freight_value)` on delivered
  orders — not the company's actual commission-based revenue, since Olist does
  not include commission-rate data.
- **Seller-level and category-level late rates are proxies, not proof of fault.**
  `is_late` is an order-level flag; multi-seller or multi-category orders
  attribute lateness to every party involved, since no per-item delivery date exists.
- **Data window:** purchase dates range 2016-09-04 to 2018-10-17, but delivered
  orders exist only up to ~Aug 2018 and the earliest months (Sep-Dec 2016) have
  too few orders for reliable monthly metrics. Most time-series analysis in this
  project uses Jan 2017 - Aug 2018 (99.7% of delivered orders).
