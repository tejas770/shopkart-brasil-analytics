-- Business question: kya late-delivery's review-score penalty sirf state-mix ka
-- artifact hai (confounding), ya har state ke ANDAR bhi hota hai?
-- Conditional aggregation gives both on-time and late averages in one pass.
-- Filtered on the LATE group's reviewed-order count (fragile small group),
-- not the state's total order count.

WITH s AS (
    SELECT
        c.customer_state,
        COUNT(*) FILTER (WHERE v.is_late) AS late_orders,
        COUNT(r.review_score) FILTER (WHERE v.is_late) AS late_reviewed,
        AVG(r.review_score) FILTER (WHERE NOT v.is_late) AS on_time_avg_score,
        AVG(r.review_score) FILTER (WHERE v.is_late) AS late_avg_score
    FROM olist.v_delivered_orders v
    JOIN olist.customers c ON c.customer_id = v.customer_id
    LEFT JOIN olist.order_reviews r ON r.order_id = v.order_id
    GROUP BY c.customer_state
)
SELECT
    customer_state,
    late_orders,
    ROUND(on_time_avg_score, 2) AS on_time_avg_score,
    ROUND(late_avg_score, 2) AS late_avg_score,
    ROUND(on_time_avg_score - late_avg_score, 2) AS score_gap
FROM s
WHERE late_reviewed >= 30
ORDER BY score_gap DESC;

-- Gap is positive in every qualifying state (range 1.63 to 2.62), so state mix
-- does not explain the delay -> low-score relationship.
