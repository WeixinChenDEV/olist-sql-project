-- Group customers by their first observed purchase month. Omit months outside the data.

WITH activity AS (
    SELECT DISTINCT customer_unique_id, DATE_TRUNC('month', purchased_at)::date AS active_month
    FROM mart.order_summary
    WHERE status = 'delivered' AND purchased_at < TIMESTAMP '2018-09-01'
), first_purchase AS (
    SELECT customer_unique_id, MIN(active_month) AS cohort_month FROM activity GROUP BY 1
), sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM first_purchase
    WHERE cohort_month >= DATE '2017-01-01' GROUP BY 1
), grid AS (
    SELECT s.*, g.month_number,
        (s.cohort_month + g.month_number * INTERVAL '1 month')::date AS active_month
    FROM sizes s
    CROSS JOIN GENERATE_SERIES(0, 6) AS g(month_number)
    WHERE s.cohort_month + g.month_number * INTERVAL '1 month' < DATE '2018-09-01'
), counts AS (
    SELECT f.cohort_month, a.active_month, COUNT(*) AS active_customers
    FROM first_purchase f JOIN activity a USING(customer_unique_id) GROUP BY 1, 2
)
SELECT g.cohort_month, g.month_number, g.cohort_size,
    COALESCE(c.active_customers, 0) AS active_customers,
    ROUND(100.0*COALESCE(c.active_customers, 0)/g.cohort_size, 2) AS purchase_retention_pct
FROM grid g LEFT JOIN counts c USING(cohort_month, active_month)
ORDER BY cohort_month, month_number;
