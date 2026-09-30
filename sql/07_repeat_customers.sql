-- Use customer_unique_id to find customers with more than one delivered order.

WITH customers AS (
    SELECT customer_unique_id, COUNT(*) AS orders, SUM(item_gmv) AS gmv_brl
    FROM mart.orders_in_period WHERE status = 'delivered' GROUP BY customer_unique_id
)
SELECT COUNT(*) AS purchasing_customers,
    COUNT(*) FILTER (WHERE orders >= 2) AS repeat_customers,
    ROUND(100.0*COUNT(*) FILTER (WHERE orders >= 2)/COUNT(*), 2) AS observed_repeat_customer_pct,
    ROUND(100.0*SUM(gmv_brl) FILTER (WHERE orders >= 2)/NULLIF(SUM(gmv_brl), 0), 2) AS repeat_customer_gmv_pct,
    MAX(orders) AS max_orders_per_customer
FROM customers;
