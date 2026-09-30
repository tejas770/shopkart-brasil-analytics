-- Business question: delivered orders me se kitne % late hue, aur avg/median delivery time kya hai?
-- Definition: late = delivered::date > estimated::date (DATE-level, not timestamp-level,
-- since estimated_delivery_date is stored at midnight). Rows with a null delivery date
-- are excluded (8 orders marked delivered but missing the date - a data inconsistency).

WITH d AS (
    SELECT
        (order_delivered_customer_date::date > order_estimated_delivery_date::date) AS is_late,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0 AS delivery_days
    FROM olist.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    ROUND(100.0 * AVG(is_late::int), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days)::numeric, 2) AS avg_delivery_days,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days))::numeric, 2) AS median_delivery_days
FROM d;

-- Expected: delivered_orders 96,470 | late_orders 6,534 | late_rate_pct 6.77
-- avg_delivery_days 12.56 | median_delivery_days 10.22
