-- Business question: kya late delivery ka review score par asli asar padta hai?
-- Uses olist.v_delivered_orders view for the shared "delivered/late" definition.
-- LEFT JOIN reviews; denominator for low_score_pct is REVIEWED orders, not all
-- delivered orders, so a differing review-response-rate between groups doesn't bias it.

SELECT
    CASE WHEN v.is_late THEN 'late' ELSE 'on_time' END AS delivery_status,
    COUNT(*) AS delivered_orders,
    COUNT(r.review_score) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / NULLIF(COUNT(r.review_score), 0), 2) AS low_score_pct
FROM olist.v_delivered_orders v
LEFT JOIN olist.order_reviews r ON r.order_id = v.order_id
GROUP BY v.is_late
ORDER BY v.is_late;

-- Expected: on_time avg 4.29 (9.27% low) | late avg 2.27 (62.42% low)
