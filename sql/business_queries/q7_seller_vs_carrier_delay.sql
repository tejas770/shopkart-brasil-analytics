-- Business question: delivery time ko seller-handling aur carrier-transit mein
-- todo. Late-rate spikes kis hisse se aate hain?
-- Invalid rows (carrier date before purchase, or delivery before carrier
-- handover - ~189 rows, a data-logging inconsistency) are excluded from the
-- day averages ONLY, not from late_rate_pct (which stays on the full set so
-- it reconciles with Q2/Q6). 3-month moving average is null until 3 rows exist.

WITH o AS (
    SELECT
        DATE_TRUNC('month', v.order_purchase_timestamp)::date AS month,
        v.is_late,
        EXTRACT(EPOCH FROM (ord.order_delivered_carrier_date - v.order_purchase_timestamp)) / 86400.0 AS seller_days,
        EXTRACT(EPOCH FROM (v.order_delivered_customer_date - ord.order_delivered_carrier_date)) / 86400.0 AS carrier_days
    FROM olist.v_delivered_orders v
    JOIN olist.orders ord ON ord.order_id = v.order_id
    WHERE v.order_purchase_timestamp >= DATE '2017-01-01'
      AND v.order_purchase_timestamp < DATE '2018-09-01'
),
m AS (
    SELECT
        month,
        AVG(seller_days) FILTER (WHERE seller_days >= 0 AND carrier_days >= 0) AS avg_seller_days,
        AVG(carrier_days) FILTER (WHERE seller_days >= 0 AND carrier_days >= 0) AS avg_carrier_days,
        AVG(is_late::int) AS late_rate
    FROM o
    GROUP BY month
)
SELECT
    month,
    ROUND(avg_seller_days::numeric, 2) AS avg_seller_days,
    ROUND(avg_carrier_days::numeric, 2) AS avg_carrier_days,
    ROUND(100 * late_rate, 2) AS late_rate_pct,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY month) >= 3
         THEN ROUND(100 * AVG(late_rate) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
    END AS late_rate_3m_avg
FROM m
ORDER BY month;

-- Carrier transit is ~75% of total delivery time and drives the Feb-Mar 2018
-- and Nov 2017 spikes; seller handling stays flat (~3 days) throughout.
