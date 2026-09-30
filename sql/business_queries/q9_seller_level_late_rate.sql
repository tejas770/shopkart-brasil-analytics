-- Business question: kaunse sellers consistently late deliver karte hain, aur
-- unka business par kitna weight (orders + GMV) hai?
-- Grain: order_items is item-level, so orders/order_id are aggregated to
-- (seller_id, order_id) pairs first. Multi-seller orders are counted as late
-- for EVERY seller involved - a documented proxy, not proof of fault, since
-- is_late is an order-level flag with no per-item delivery date available.
-- Sellers with < 20 orders excluded (small-sample noise).

WITH seller_orders AS (
    SELECT
        oi.seller_id,
        v.order_id,
        v.is_late,
        SUM(oi.price + oi.freight_value) AS order_seller_gmv
    FROM olist.v_delivered_orders v
    JOIN olist.order_items oi ON v.order_id = oi.order_id
    GROUP BY oi.seller_id, v.order_id, v.is_late
)
SELECT
    so.seller_id,
    s.seller_state,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE so.is_late) / COUNT(*), 2) AS late_rate_pct,
    ROUND(SUM(so.order_seller_gmv), 2) AS total_gmv
FROM seller_orders so
JOIN olist.sellers s ON so.seller_id = s.seller_id
GROUP BY so.seller_id, s.seller_state
HAVING COUNT(*) >= 20
ORDER BY late_rate_pct DESC, orders DESC;

-- Worst late-rate sellers (>20%) are all small (20-96 orders, low GMV).
-- The largest sellers by volume (500-1800+ orders) sit at 5-10.5% late rate,
-- near or below the company average - the delay problem is not seller-concentrated.
