-- Rank categories using item prices from delivered orders.

WITH totals AS (
    SELECT COALESCE(c.category_en, p.category_pt, 'unknown') AS category,
        COUNT(*) AS item_rows, COUNT(DISTINCT i.order_id) AS orders,
        SUM(i.price) AS delivered_gmv_brl, SUM(i.freight) AS freight_brl
    FROM core.order_items i JOIN mart.orders_in_period f USING(order_id)
    JOIN core.products p USING(product_id)
    LEFT JOIN core.categories c ON p.category_pt = c.category_pt
    WHERE f.status = 'delivered' GROUP BY 1
)
SELECT *, DENSE_RANK() OVER (ORDER BY delivered_gmv_brl DESC) AS gmv_rank,
    ROUND(100.0*delivered_gmv_brl/NULLIF(SUM(delivered_gmv_brl) OVER (), 0), 2) AS gmv_share_pct,
    ROUND(100.0*freight_brl/NULLIF(delivered_gmv_brl, 0), 2) AS freight_to_gmv_pct
FROM totals ORDER BY gmv_rank, category;
