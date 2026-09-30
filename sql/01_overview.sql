-- Basic order totals. Item GMV excludes shipping fees.

SELECT COUNT(*) AS orders,
    COUNT(*) FILTER (WHERE status = 'delivered') AS delivered_orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    MIN(purchased_at) AS first_purchase, MAX(purchased_at) AS last_purchase,
    SUM(item_gmv) AS all_status_item_gmv_brl,
    SUM(item_gmv) FILTER (WHERE status = 'delivered') AS delivered_item_gmv_brl,
    SUM(payment_total) AS recorded_payments_brl,
    ROUND(AVG(item_gmv) FILTER (WHERE status = 'delivered'), 2) AS delivered_avg_order_gmv_brl,
    COUNT(is_late) AS delivery_eligible_orders,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    ROUND(100.0*COUNT(*) FILTER (WHERE is_late)/NULLIF(COUNT(is_late), 0), 2) AS late_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY delivery_days))::numeric, 2) AS median_delivery_days
FROM mart.order_summary;
