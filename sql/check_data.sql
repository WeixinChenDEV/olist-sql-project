-- Anomalies are findings, not necessarily failed invariants.
SELECT 'orders_without_items' AS issue, COUNT(*) AS affected_rows
    FROM mart.order_summary WHERE item_count = 0
UNION ALL SELECT 'orders_without_payments', COUNT(*) FROM mart.order_summary WHERE payment_count = 0
UNION ALL SELECT 'orders_without_reviews', COUNT(*) FROM mart.order_summary WHERE review_score IS NULL
UNION ALL SELECT 'delivered_missing_delivery_timestamp', COUNT(*) FROM core.orders
    WHERE status = 'delivered' AND delivered_at IS NULL
UNION ALL SELECT 'delivery_before_purchase', COUNT(*) FROM core.orders WHERE delivered_at < purchased_at
UNION ALL SELECT 'carrier_before_purchase', COUNT(*) FROM core.orders WHERE carrier_at < purchased_at
UNION ALL SELECT 'approval_before_purchase', COUNT(*) FROM core.orders WHERE approved_at < purchased_at
UNION ALL SELECT 'products_without_category', COUNT(*) FROM core.products WHERE category_pt IS NULL
UNION ALL SELECT 'products_without_translation', COUNT(*) FROM core.products p
    LEFT JOIN core.categories c ON p.category_pt = c.category_pt
    WHERE p.category_pt IS NOT NULL AND c.category_pt IS NULL
UNION ALL SELECT 'orders_with_multiple_reviews', COUNT(*) FROM
    (SELECT order_id FROM core.order_reviews GROUP BY order_id HAVING COUNT(*) > 1) r
UNION ALL SELECT 'reused_review_ids', COUNT(*) FROM
    (SELECT review_id FROM core.order_reviews GROUP BY review_id HAVING COUNT(*) > 1) r
UNION ALL SELECT 'orders_with_multiple_payments', COUNT(*) FROM mart.order_summary WHERE payment_count > 1
UNION ALL SELECT 'orders_with_multiple_items', COUNT(*) FROM mart.order_summary WHERE item_count > 1
UNION ALL SELECT 'orders_with_multiple_sellers', COUNT(*) FROM mart.order_summary WHERE seller_count > 1
UNION ALL SELECT 'payment_vs_item_plus_freight_difference_gt_1_brl', COUNT(*) FROM mart.order_summary
    WHERE payment_count > 0 AND item_count > 0 AND ABS(payment_total-item_gmv-freight) > 1
ORDER BY issue;
