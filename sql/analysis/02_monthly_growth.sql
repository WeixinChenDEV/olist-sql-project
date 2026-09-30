-- Main purchase-month window. Delivered GMV is attributed to purchase month.
WITH monthly AS (
 SELECT DATE_TRUNC('month',purchased_at)::date AS month,COUNT(*) AS orders,
  COUNT(*) FILTER(WHERE status='delivered') AS delivered_orders,
  COUNT(*) FILTER(WHERE status='canceled') AS canceled_orders,
  SUM(item_gmv) FILTER(WHERE status='delivered') AS delivered_gmv_brl,
  COUNT(is_late) AS eligible_deliveries,
  COUNT(*) FILTER(WHERE is_late) AS late_orders
 FROM mart.analysis_orders GROUP BY 1
), lagged AS (
 SELECT *,LAG(delivered_gmv_brl) OVER(ORDER BY month) AS previous_gmv
 FROM monthly
)
SELECT month,orders,delivered_orders,delivered_gmv_brl,
 ROUND(delivered_gmv_brl/NULLIF(delivered_orders,0),2) AS avg_order_gmv_brl,
 ROUND(100.0*(delivered_gmv_brl-previous_gmv)/NULLIF(previous_gmv,0),2) AS gmv_mom_pct,
 ROUND(100.0*canceled_orders/NULLIF(orders,0),2) AS canceled_pct,
 ROUND(100.0*late_orders/NULLIF(eligible_deliveries,0),2) AS late_pct
FROM lagged ORDER BY month;
