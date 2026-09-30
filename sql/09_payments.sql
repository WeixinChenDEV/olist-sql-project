-- Check recorded payments against item prices plus shipping fees.

SELECT status, COUNT(*) AS orders_with_items_and_payments,
    COUNT(*) FILTER (WHERE ABS(payment_total-item_gmv-freight) <= 0.01) AS matched_to_cent,
    COUNT(*) FILTER (WHERE ABS(payment_total-item_gmv-freight) > 1) AS difference_gt_1_brl,
    SUM(payment_total) AS payment_total_brl, SUM(item_gmv+freight) AS item_plus_freight_brl,
    SUM(payment_total-item_gmv-freight) AS net_difference_brl
FROM mart.order_summary WHERE item_count > 0 AND payment_count > 0
GROUP BY status ORDER BY orders_with_items_and_payments DESC;
