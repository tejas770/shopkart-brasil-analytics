-- Business Case #2: Support Lead claimed complaints (low review scores) rose
-- in H1 2018 vs H1 2017. Finding: confirmed and explained - see decomposition below.

-- Step 1: data-completeness check (review coverage stable ~99% both periods, no censoring concern)
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
    COUNT(*) AS delivered_orders,
    COUNT(r.review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(r.review_score) / COUNT(*), 2) AS review_coverage_pct
FROM olist.v_delivered_orders v
LEFT JOIN olist.order_reviews r ON r.order_id = v.order_id
WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-07-01'
GROUP BY 1 ORDER BY 1;

-- Step 2: overall low-score rate, H1 2017 vs H1 2018
-- (low score = review_score <= 2; denominator is reviewed orders)
SELECT
    CASE
        WHEN v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01' THEN 'Jan-Jun 2017'
        WHEN v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01' THEN 'Jan-Jun 2018'
    END AS period,
    COUNT(*) AS delivered_orders,
    COUNT(r.review_score) AS reviewed_orders,
    COUNT(*) FILTER (WHERE r.review_score <= 2) AS low_score_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / NULLIF(COUNT(r.review_score), 0), 2) AS low_score_rate_pct
FROM olist.v_delivered_orders v
LEFT JOIN olist.order_reviews r ON r.order_id = v.order_id
WHERE (v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01')
   OR (v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01')
GROUP BY 1
ORDER BY 1;
-- Result: 11.13% (2017) -> 14.54% (2018), statistically significant (two-proportion
-- z-test: z=10.07, p~7.6e-24)

-- Step 3: late-delivery rate, same periods (tests the "is it just more delays?" hypothesis)
SELECT
    CASE
        WHEN v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01' THEN 'Jan-Jun 2017'
        WHEN v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01' THEN 'Jan-Jun 2018'
    END AS period,
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (WHERE v.is_late) AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE v.is_late) / COUNT(*), 2) AS late_rate_pct
FROM olist.v_delivered_orders v
WHERE (v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01')
   OR (v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01')
GROUP BY 1
ORDER BY 1;
-- Result: late rate more than doubled, 3.87% -> 8.63%

-- Step 4: 4-way breakdown (period x on-time/late) to decompose the low-score-rate
-- increase into "more orders became late" (mix-shift) vs "each group's own rate got worse"
SELECT
    CASE
        WHEN v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01' THEN '2017'
        WHEN v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01' THEN '2018'
    END AS period,
    CASE WHEN v.is_late THEN 'late' ELSE 'on_time' END AS delivery_status,
    COUNT(*) AS orders,
    COUNT(r.review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / NULLIF(COUNT(r.review_score), 0), 2) AS low_score_rate_pct
FROM olist.v_delivered_orders v
LEFT JOIN olist.order_reviews r ON r.order_id = v.order_id
WHERE (v.order_purchase_timestamp >= DATE '2017-01-01' AND v.order_purchase_timestamp < DATE '2017-07-01')
   OR (v.order_purchase_timestamp >= DATE '2018-01-01' AND v.order_purchase_timestamp < DATE '2018-07-01')
GROUP BY 1, 2
ORDER BY 1, 2;
-- Result: on-time rate stayed ~stable (9.32% -> 9.75%), late rate rose modestly
-- (57.98% -> 66.00%), but late orders' SHARE of all orders grew sharply
-- (3.87% -> 8.63%). Decomposition: 68.5% of the total increase came from this
-- mix-shift (more orders becoming late), only 31.5% from within-group score
-- deterioration. Conclusion: this is a downstream symptom of the delivery-delay
-- problem (see q8/business case findings), not a separate quality issue.
