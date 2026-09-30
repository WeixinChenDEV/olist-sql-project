-- Add only after measuring the unindexed predicate; retain native PK indexes.
CREATE INDEX IF NOT EXISTS orders_purchased_at_idx ON core.orders(purchased_at);
CREATE INDEX IF NOT EXISTS reviews_order_time_idx
    ON core.order_reviews(order_id, answered_at DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS order_items_seller_idx ON core.order_items(seller_id);
CREATE INDEX IF NOT EXISTS order_summary_purchase_idx ON mart.order_summary(purchased_at);
ANALYZE core.orders;
ANALYZE core.order_reviews;
ANALYZE core.order_items;
ANALYZE mart.order_summary;
