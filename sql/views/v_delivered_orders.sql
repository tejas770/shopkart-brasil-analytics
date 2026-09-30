-- Single source of truth for "delivered order" KPI logic, so every downstream
-- query uses the same definition:
--   - order_status = 'delivered' AND delivery date is present
--   - is_late uses a DATE-level comparison (not timestamp-level), because
--     order_estimated_delivery_date is stored at midnight; a timestamp-level
--     comparison would wrongly flag same-day deliveries as late
--   - delivery_days is a continuous fractional value (purchase -> delivery)

CREATE OR REPLACE VIEW olist.v_delivered_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    (
        o.order_delivered_customer_date::date
        > o.order_estimated_delivery_date::date
    ) AS is_late,
    EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_purchase_timestamp
        )
    ) / 86400.0 AS delivery_days
FROM olist.orders o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

-- Expected row count: 96,470
