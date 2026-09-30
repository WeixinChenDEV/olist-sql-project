-- Association, not causal effect. Latest review selected once per order.
SELECT CASE WHEN is_late THEN 'late' ELSE 'on_time' END AS delivery_group,
 COUNT(*) AS eligible_delivered_orders,
 COUNT(review_score) AS reviewed_orders,
 ROUND(100.0*COUNT(review_score)/COUNT(*),2) AS review_coverage_pct,
 ROUND(AVG(review_score),2) AS avg_review_score,
 COUNT(*) FILTER(WHERE review_score<=2) AS low_score_orders,
 ROUND(100.0*COUNT(*) FILTER(WHERE review_score<=2)/NULLIF(COUNT(review_score),0),2) AS low_score_pct
FROM mart.analysis_orders WHERE is_late IS NOT NULL
GROUP BY is_late ORDER BY is_late DESC;
