-- Convert the CSV text columns to useful types. Keep missing values as NULL.
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE core.customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    zip_prefix text, city text, state text
);
INSERT INTO core.customers SELECT customer_id, customer_unique_id,
    customer_zip_code_prefix, customer_city, customer_state FROM raw.customers;

CREATE TABLE core.sellers (
    seller_id text PRIMARY KEY, zip_prefix text, city text, state text
);
INSERT INTO core.sellers SELECT seller_id, seller_zip_code_prefix,
    seller_city, seller_state FROM raw.sellers;

CREATE TABLE core.categories (
    category_pt text PRIMARY KEY, category_en text NOT NULL
);
INSERT INTO core.categories SELECT product_category_name,
    product_category_name_english FROM raw.product_category_name_translation;

CREATE TABLE core.products (
    product_id text PRIMARY KEY, category_pt text,
    name_length integer, description_length integer, photos integer,
    weight_g numeric, length_cm numeric, height_cm numeric, width_cm numeric
);
-- Categories without an English translation remain valid source categories.
INSERT INTO core.products SELECT product_id, NULLIF(product_category_name, ''),
    NULLIF(product_name_lenght, '')::integer,
    NULLIF(product_description_lenght, '')::integer,
    NULLIF(product_photos_qty, '')::integer,
    NULLIF(product_weight_g, '')::numeric,
    NULLIF(product_length_cm, '')::numeric,
    NULLIF(product_height_cm, '')::numeric,
    NULLIF(product_width_cm, '')::numeric FROM raw.products;

CREATE TABLE core.orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES core.customers(customer_id),
    status text NOT NULL, purchased_at timestamp NOT NULL,
    approved_at timestamp, carrier_at timestamp, delivered_at timestamp,
    estimated_at timestamp
);
INSERT INTO core.orders SELECT order_id, customer_id, order_status,
    NULLIF(order_purchase_timestamp, '')::timestamp,
    NULLIF(order_approved_at, '')::timestamp,
    NULLIF(order_delivered_carrier_date, '')::timestamp,
    NULLIF(order_delivered_customer_date, '')::timestamp,
    NULLIF(order_estimated_delivery_date, '')::timestamp FROM raw.orders;

CREATE TABLE core.order_items (
    order_id text REFERENCES core.orders(order_id), item_number integer,
    product_id text NOT NULL REFERENCES core.products(product_id),
    seller_id text NOT NULL REFERENCES core.sellers(seller_id),
    shipping_limit_at timestamp, price numeric(14, 2) NOT NULL CHECK(price >= 0),
    freight numeric(14, 2) NOT NULL CHECK(freight >= 0),
    PRIMARY KEY(order_id, item_number)
);
INSERT INTO core.order_items SELECT order_id, order_item_id::integer,
    product_id, seller_id, NULLIF(shipping_limit_date, '')::timestamp,
    price::numeric, freight_value::numeric FROM raw.order_items;

CREATE TABLE core.order_payments (
    order_id text REFERENCES core.orders(order_id), payment_number integer,
    payment_type text NOT NULL, installments integer,
    payment_value numeric(14, 2) NOT NULL CHECK(payment_value >= 0),
    PRIMARY KEY(order_id, payment_number)
);
INSERT INTO core.order_payments SELECT order_id, payment_sequential::integer,
    payment_type, payment_installments::integer, payment_value::numeric
    FROM raw.order_payments;

CREATE TABLE core.order_reviews (
    source_row bigint PRIMARY KEY, review_id text NOT NULL,
    order_id text NOT NULL REFERENCES core.orders(order_id),
    score integer NOT NULL CHECK(score BETWEEN 1 AND 5),
    title text, message text, created_at timestamp, answered_at timestamp
);
-- review_id and order_id are NOT unique in the source. Keep every row.
INSERT INTO core.order_reviews SELECT source_row, review_id, order_id,
    review_score::integer, NULLIF(review_comment_title, ''),
    NULLIF(review_comment_message, ''), NULLIF(review_creation_date, '')::timestamp,
    NULLIF(review_answer_timestamp, '')::timestamp FROM raw.order_reviews;

CREATE VIEW mart.latest_review AS
SELECT source_row, review_id, order_id, score, created_at, answered_at
FROM (
    SELECT r.*, ROW_NUMBER() OVER (
        PARTITION BY order_id
        ORDER BY answered_at DESC NULLS LAST,
                 created_at DESC NULLS LAST,
                 review_id DESC, source_row DESC
    ) AS rn
    FROM core.order_reviews r
) ranked WHERE rn = 1;

-- Sum items and payments separately before joining them to orders.
CREATE MATERIALIZED VIEW mart.order_summary AS
WITH items AS (
    SELECT order_id, COUNT(*) AS item_count, COUNT(DISTINCT seller_id) AS seller_count,
        SUM(price) AS item_gmv, SUM(freight) AS freight
    FROM core.order_items GROUP BY order_id
), payments AS (
    SELECT order_id, COUNT(*) AS payment_count, SUM(payment_value) AS payment_total
    FROM core.order_payments GROUP BY order_id
)
SELECT o.*, c.customer_unique_id, c.state AS customer_state,
    COALESCE(i.item_count, 0) AS item_count, COALESCE(i.seller_count, 0) AS seller_count,
    COALESCE(i.item_gmv, 0)::numeric(14, 2) AS item_gmv,
    COALESCE(i.freight, 0)::numeric(14, 2) AS freight,
    COALESCE(p.payment_count, 0) AS payment_count,
    COALESCE(p.payment_total, 0)::numeric(14, 2) AS payment_total,
    r.score AS review_score,
    -- Compare dates so delivery on the estimated day counts as on time.
    CASE
        WHEN o.status = 'delivered'
             AND o.delivered_at >= o.purchased_at
             AND o.estimated_at IS NOT NULL
        THEN o.delivered_at::date > o.estimated_at::date
    END AS is_late,
    CASE
        WHEN o.status = 'delivered' AND o.delivered_at >= o.purchased_at
        THEN EXTRACT(EPOCH FROM (o.delivered_at - o.purchased_at)) / 86400.0
    END AS delivery_days
FROM core.orders o
JOIN core.customers c USING (customer_id)
LEFT JOIN items i USING (order_id)
LEFT JOIN payments p USING (order_id)
LEFT JOIN mart.latest_review r USING (order_id);
CREATE UNIQUE INDEX order_summary_pk ON mart.order_summary(order_id);

-- One row per seller and order. Delivery and review belong to the whole order.
CREATE MATERIALIZED VIEW mart.seller_orders AS
SELECT i.seller_id, i.order_id, SUM(i.price) AS item_gmv,
    MAX(f.purchased_at) AS purchased_at, MAX(f.status) AS status,
    BOOL_OR(f.is_late) AS is_late, MAX(f.review_score) AS review_score,
    MAX(f.seller_count) AS seller_count
FROM core.order_items i JOIN mart.order_summary f USING(order_id)
GROUP BY i.seller_id, i.order_id;
CREATE UNIQUE INDEX seller_orders_pk ON mart.seller_orders(seller_id, order_id);

-- Use the same period in the main analysis queries.
CREATE VIEW mart.orders_in_period AS
SELECT * FROM mart.order_summary
WHERE purchased_at >= TIMESTAMP '2017-01-01'
  AND purchased_at < TIMESTAMP '2018-09-01';
ANALYZE;
