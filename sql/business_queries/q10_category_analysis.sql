-- Business question: kya bulky/heavy product categories mein zyada delay hota hai?
-- Same seller-style grain issue: order_items -> (category, order_id) pairs first,
-- then bool_or(is_late) since is_late is constant within an order. Categories
-- with < 30 orders excluded. avg_weight_g is catalog-level (all products in the
-- category), not sales-weighted by what was actually shipped - a documented limitation.

WITH item_level AS (
    SELECT
        p.product_category_name_english AS category,
        v.order_id,
        v.is_late,
        (oi.price + oi.freight_value) AS item_gmv
    FROM olist.v_delivered_orders v
    JOIN olist.order_items oi ON oi.order_id = v.order_id
    JOIN olist.products p ON p.product_id = oi.product_id
),
category_order AS (
    SELECT category, order_id, bool_or(is_late) AS is_late, SUM(item_gmv) AS gmv
    FROM item_level
    GROUP BY category, order_id
),
cat_weight AS (
    SELECT product_category_name_english AS category, AVG(product_weight_g) AS avg_weight_g
    FROM olist.products
    GROUP BY product_category_name_english
)
SELECT
    co.category,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE co.is_late) / COUNT(*), 2) AS late_rate_pct,
    ROUND(w.avg_weight_g, 2) AS avg_weight_g,
    ROUND(SUM(co.gmv), 2) AS total_gmv
FROM category_order co
JOIN cat_weight w ON w.category = co.category
GROUP BY co.category, w.avg_weight_g
HAVING COUNT(*) >= 30
ORDER BY late_rate_pct DESC;

-- Correlation between avg_weight_g and late_rate_pct across categories is only
-- 0.21 (weak) - the "bulky products are slower" hypothesis is not well supported,
-- with furniture_mattress_and_upholstery and office_furniture as the main exceptions.
