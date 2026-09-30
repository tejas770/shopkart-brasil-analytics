-- Business question: month-by-month delivered orders, GMV aur late rate kaise
-- badle hain, aur GMV ka MoM growth kya hai?
-- order_items aggregated to order-level FIRST (item_gmv CTE) to avoid fan-out.
-- Window restricted to Jan 2017 - Aug 2018: earlier/later months have too few
-- orders for meaningful MoM % (e.g. Dec 2016 had 1 delivered order).

WITH item_gmv AS (
    SELECT order_id, SUM(price + freight_value) AS gmv
    FROM olist.order_items
    GROUP BY order_id
),
monthly AS (
    SELECT
        DATE_TRUNC('month', v.order_purchase_timestamp)::date AS month,
        COUNT(*) AS delivered_orders,
        SUM(g.gmv) AS gmv,
        AVG(v.is_late::int) AS late_rate
    FROM olist.v_delivered_orders v
    JOIN item_gmv g ON g.order_id = v.order_id
    WHERE v.order_purchase_timestamp >= DATE '2017-01-01'
      AND v.order_purchase_timestamp < DATE '2018-09-01'
    GROUP BY 1
)
SELECT
    month,
    delivered_orders,
    ROUND(gmv, 2) AS gmv,
    ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY month)) / NULLIF(LAG(gmv) OVER (ORDER BY month), 0), 2) AS gmv_mom_growth_pct,
    ROUND(100.0 * late_rate, 2) AS late_rate_pct
FROM monthly
ORDER BY month;

-- Notable: Nov 2017 GMV +53.54% MoM alongside late-rate spike (4.18% -> 12.40%),
-- consistent with a Black Friday demand surge.
