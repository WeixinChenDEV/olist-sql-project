-- Separate denominator for eligible timestamps; suppress small state samples.
SELECT customer_state,COUNT(*) AS delivered_orders,COUNT(is_late) AS eligible_orders,
 COUNT(*) FILTER(WHERE is_late) AS late_orders,
 ROUND(100.0*COUNT(*) FILTER(WHERE is_late)/NULLIF(COUNT(is_late),0),2) AS late_pct,
 ROUND(AVG(delivery_days),2) AS avg_delivery_days,
 ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP(ORDER BY delivery_days))::numeric,2) AS p90_delivery_days
FROM mart.analysis_orders WHERE status='delivered'
GROUP BY customer_state HAVING COUNT(is_late)>=100
ORDER BY late_pct DESC,eligible_orders DESC;
