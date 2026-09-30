-- Business Case #1: CFO claimed Q1 2018 GMV was 20% lower than Q4 2017.
-- Finding: it was NOT lower - it increased. The premise itself was false;
-- lesson is to verify a stakeholder's claim before diagnosing a root cause.

-- Query A: quarter defined by PURCHASE date (order-level grain, avoids fan-out)
WITH order_level AS (
    SELECT
        o.order_id,
        DATE_TRUNC('quarter', o.order_purchase_timestamp)::date AS quarter,
        o.order_status,
        SUM(oi.price + oi.freight_value) AS order_gmv
    FROM olist.orders o
    LEFT JOIN olist.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_purchase_timestamp >= DATE '2017-10-01'
      AND o.order_purchase_timestamp <  DATE '2018-04-01'
    GROUP BY o.order_id, DATE_TRUNC('quarter', o.order_purchase_timestamp)::date, o.order_status
)
SELECT
    quarter,
    COUNT(*) AS all_orders,
    ROUND(SUM(order_gmv), 2) AS all_orders_gmv,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
    ROUND(SUM(order_gmv) FILTER (WHERE order_status = 'delivered'), 2) AS delivered_gmv,
    ROUND(
        SUM(order_gmv) FILTER (WHERE order_status = 'delivered')
        / NULLIF(COUNT(*) FILTER (WHERE order_status = 'delivered'), 0),
        2
    ) AS aov
FROM order_level
GROUP BY quarter
ORDER BY quarter;
-- Result: Q4 2017 delivered_gmv 2,747,559.50 -> Q1 2018 3,164,654.11 (+15.2%)

-- Query B: quarter defined by DELIVERY date, to test whether time-basis explains the claim
WITH delivered_order_level AS (
    SELECT
        o.order_id,
        DATE_TRUNC('quarter', o.order_delivered_customer_date)::date AS quarter,
        SUM(oi.price + oi.freight_value) AS order_gmv
    FROM olist.orders o
    JOIN olist.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_customer_date >= TIMESTAMP '2017-10-01'
      AND o.order_delivered_customer_date <  TIMESTAMP '2018-04-01'
    GROUP BY o.order_id, DATE_TRUNC('quarter', o.order_delivered_customer_date)::date
)
SELECT
    quarter,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(order_gmv), 2) AS delivered_gmv,
    ROUND(AVG(order_gmv), 2) AS aov
FROM delivered_order_level
GROUP BY quarter
ORDER BY quarter;
-- Result: still an increase (+11.3%) on delivery-date basis - time-basis does
-- not explain the CFO's claim either. Conclusion: reconcile the CFO's source
-- report/metric/baseline before doing any root-cause analysis.
