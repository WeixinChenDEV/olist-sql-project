-- Every row must pass; the runner exits nonzero on failure.
WITH checks AS (
 SELECT 'order_grain_preserved' AS check_name,
  (SELECT COUNT(*) FROM mart.order_fact)=(SELECT COUNT(*) FROM core.orders) AS passed
 UNION ALL SELECT 'one_fact_row_per_order',COUNT(*)=COUNT(DISTINCT order_id) FROM mart.order_fact
 UNION ALL SELECT 'item_gmv_reconciles',
  (SELECT SUM(item_gmv) FROM mart.order_fact)=(SELECT SUM(price) FROM core.order_items)
 UNION ALL SELECT 'freight_reconciles',
  (SELECT SUM(freight) FROM mart.order_fact)=(SELECT SUM(freight) FROM core.order_items)
 UNION ALL SELECT 'payment_total_reconciles',
  (SELECT SUM(payment_total) FROM mart.order_fact)=(SELECT SUM(payment_value) FROM core.order_payments)
 UNION ALL SELECT 'latest_review_unique',COUNT(*)=COUNT(DISTINCT order_id) FROM mart.latest_review
 UNION ALL SELECT 'latest_review_covers_reviewed_orders',
  (SELECT COUNT(*) FROM mart.latest_review)=(SELECT COUNT(DISTINCT order_id) FROM core.order_reviews)
 UNION ALL SELECT 'raw_reviews_preserved',
  (SELECT COUNT(*) FROM raw.order_reviews)=(SELECT COUNT(*) FROM core.order_reviews)
 UNION ALL SELECT 'seller_gmv_reconciles',
  (SELECT SUM(item_gmv) FROM mart.seller_order_fact)=(SELECT SUM(price) FROM core.order_items)
 UNION ALL SELECT 'delivery_days_nonnegative',COUNT(*)=0 FROM mart.order_fact WHERE delivery_days<0
 UNION ALL SELECT 'late_flag_requires_valid_delivered_order',COUNT(*)=0 FROM mart.order_fact
  WHERE is_late IS NOT NULL AND (status<>'delivered' OR delivered_at IS NULL
   OR estimated_at IS NULL OR delivered_at<purchased_at)
 UNION ALL SELECT 'analysis_window_is_20_months',COUNT(DISTINCT DATE_TRUNC('month',purchased_at))=20
  FROM mart.analysis_orders
)
SELECT * FROM checks ORDER BY check_name;
