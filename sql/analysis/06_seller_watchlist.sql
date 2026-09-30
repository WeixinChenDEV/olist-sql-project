-- Single-seller orders avoid attaching one shared outcome to multiple sellers.
WITH metrics AS (
 SELECT s.seller_id,COUNT(*) AS eligible_orders,
  COUNT(*) FILTER(WHERE s.is_late) AS late_orders,
  SUM(s.item_gmv) AS delivered_gmv_brl,
  ROUND(100.0*COUNT(*) FILTER(WHERE s.is_late)/COUNT(*),2) AS late_pct,
  COUNT(s.review_score) AS reviewed_orders,
  ROUND(AVG(s.review_score),2) AS avg_review_score
 FROM mart.seller_order_fact s
 WHERE s.purchased_at>=TIMESTAMP '2017-01-01' AND s.purchased_at<TIMESTAMP '2018-09-01'
  AND s.seller_count=1 AND s.is_late IS NOT NULL
 GROUP BY s.seller_id HAVING COUNT(*)>=100
)
SELECT m.*,s.state AS seller_state,
 DENSE_RANK() OVER(ORDER BY late_orders DESC) AS late_volume_rank
FROM metrics m JOIN core.sellers s USING(seller_id)
ORDER BY late_volume_rank,late_pct DESC,seller_id;
