-- Business question: delivered orders ka total count, total revenue (GMV), aur AOV kya hai?
-- GMV = price + freight_value, sirf delivered orders. Order-level grain first
-- (via subquery) so AOV = per-order revenue average, no fan-out from order_items.

SELECT
    COUNT(*) AS total_orders,
    ROUND(SUM(order_revenue), 2) AS total_revenue,
    ROUND(AVG(order_revenue), 2) AS aov
FROM (
    SELECT oi.order_id, SUM(oi.price + oi.freight_value) AS order_revenue
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
) t;

-- Expected: total_orders 96,478 | total_revenue 15,419,773.75 | aov 159.83
