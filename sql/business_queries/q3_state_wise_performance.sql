-- Business question: kaunse states mein delivery performance sabse kharab hai,
-- aur kya wahan customer satisfaction bhi kam hai?
-- LEFT JOIN reviews (not every delivered order has one). States with < 100
-- delivered orders excluded - percentages on small samples are unstable.

WITH d AS (
    SELECT
        c.customer_state,
        (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS is_late,
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 AS delivery_days,
        r.review_score
    FROM olist.orders o
    JOIN olist.customers c ON c.customer_id = o.customer_id
    LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(100.0 * AVG(is_late::int), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days)::numeric, 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM d
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_rate_pct DESC;

-- Worst late rates (all Northeast Brazil): AL 21.41%, MA 17.43%, SE 15.22%,
-- PI 13.87%, CE 13.76%, BA 12.16%
