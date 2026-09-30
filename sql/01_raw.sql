-- Raw CSV columns are preserved as text. Typed transformations are in 02_model.sql.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE TABLE raw.customers (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, customer_id text, customer_unique_id text, customer_zip_code_prefix text, customer_city text, customer_state text);
CREATE TABLE raw.order_items (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, order_id text, order_item_id text, product_id text, seller_id text, shipping_limit_date text, price text, freight_value text);
CREATE TABLE raw.order_payments (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, order_id text, payment_sequential text, payment_type text, payment_installments text, payment_value text);
CREATE TABLE raw.order_reviews (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, review_id text, order_id text, review_score text, review_comment_title text, review_comment_message text, review_creation_date text, review_answer_timestamp text);
CREATE TABLE raw.orders (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, order_id text, customer_id text, order_status text, order_purchase_timestamp text, order_approved_at text, order_delivered_carrier_date text, order_delivered_customer_date text, order_estimated_delivery_date text);
CREATE TABLE raw.products (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, product_id text, product_category_name text, product_name_lenght text, product_description_lenght text, product_photos_qty text, product_weight_g text, product_length_cm text, product_height_cm text, product_width_cm text);
CREATE TABLE raw.sellers (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, seller_id text, seller_zip_code_prefix text, seller_city text, seller_state text);
CREATE TABLE raw.product_category_name_translation (source_row bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, product_category_name text, product_category_name_english text);
