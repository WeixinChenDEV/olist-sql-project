-- Compare a direct join with order-level totals for Jan 2018.

WITH correct AS (
    SELECT SUM(i.price) AS correct_gmv
    FROM core.order_items i JOIN core.orders o USING(order_id)
    WHERE o.purchased_at >= TIMESTAMP '2018-01-01' AND o.purchased_at < TIMESTAMP '2018-02-01'
), naive AS (
    SELECT SUM(i.price) AS naive_gmv
    FROM core.orders o JOIN core.order_items i USING(order_id)
    JOIN core.order_payments p USING(order_id)
    JOIN core.order_reviews r USING(order_id)
    WHERE o.purchased_at >= TIMESTAMP '2018-01-01' AND o.purchased_at < TIMESTAMP '2018-02-01'
), safe AS (
    SELECT SUM(item_gmv) AS safe_gmv FROM mart.order_summary
    WHERE purchased_at >= TIMESTAMP '2018-01-01' AND purchased_at < TIMESTAMP '2018-02-01'
)
SELECT *, ROUND(100.0*(naive_gmv-correct_gmv)/correct_gmv, 2) AS naive_error_pct,
    safe_gmv = correct_gmv AS safe_join_reconciles
FROM correct CROSS JOIN naive CROSS JOIN safe;
