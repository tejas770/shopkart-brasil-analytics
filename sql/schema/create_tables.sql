-- ShopKart Brasil / Olist analytics database
-- Run this file top to bottom on a fresh PostgreSQL instance.

CREATE DATABASE shopkart_analytics;

-- Connect to shopkart_analytics before running the rest (e.g. \c shopkart_analytics in psql)

CREATE SCHEMA olist;

-- Tables with no foreign keys first
CREATE TABLE olist.customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_unique_id VARCHAR NOT NULL,
    customer_zip_code_prefix VARCHAR,
    customer_city VARCHAR,
    customer_state VARCHAR
);

CREATE TABLE olist.products (
    product_id VARCHAR PRIMARY KEY,
    product_category_name VARCHAR,
    product_name_lenght NUMERIC,
    product_description_lenght NUMERIC,
    product_photos_qty NUMERIC,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC
);

CREATE TABLE olist.sellers (
    seller_id VARCHAR PRIMARY KEY,
    seller_zip_code_prefix VARCHAR,
    seller_city VARCHAR,
    seller_state VARCHAR
);

CREATE TABLE olist.category_translation (
    product_category_name VARCHAR PRIMARY KEY,
    product_category_name_english VARCHAR
);

CREATE TABLE olist.geolocation (
    geolocation_zip_code_prefix VARCHAR,
    geolocation_lat NUMERIC,
    geolocation_lng NUMERIC,
    geolocation_city VARCHAR,
    geolocation_state VARCHAR
);

-- Tables that reference customers
CREATE TABLE olist.orders (
    order_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR NOT NULL REFERENCES olist.customers(customer_id),
    order_status VARCHAR NOT NULL,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- Tables that reference orders / products / sellers
CREATE TABLE olist.order_items (
    order_id VARCHAR NOT NULL REFERENCES olist.orders(order_id),
    order_item_id INT NOT NULL,
    product_id VARCHAR NOT NULL REFERENCES olist.products(product_id),
    seller_id VARCHAR NOT NULL REFERENCES olist.sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price NUMERIC NOT NULL,
    freight_value NUMERIC NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE olist.order_payments (
    order_id VARCHAR NOT NULL REFERENCES olist.orders(order_id),
    payment_sequential INT NOT NULL,
    payment_type VARCHAR,
    payment_installments INT,
    payment_value NUMERIC,
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is not unique per order in the raw data (some orders have 2+ reviews).
-- After ETL dedupes to one row per order (keeping the latest review_answer_timestamp),
-- order_id becomes the real primary key.
CREATE TABLE olist.order_reviews (
    review_id VARCHAR,
    order_id VARCHAR NOT NULL REFERENCES olist.orders(order_id),
    review_score INT NOT NULL,
    review_comment_title VARCHAR,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

ALTER TABLE olist.order_reviews ADD PRIMARY KEY (order_id);

-- English category name, populated during ETL (falls back to 'unknown' when
-- the category is missing or has no translation match)
ALTER TABLE olist.products ADD COLUMN product_category_name_english TEXT;

-- Indexes on FK / join columns (PostgreSQL does not auto-index these)
CREATE INDEX idx_orders_customer ON olist.orders(customer_id);
CREATE INDEX idx_orders_status ON olist.orders(order_status);
CREATE INDEX idx_items_product ON olist.order_items(product_id);
CREATE INDEX idx_items_seller ON olist.order_items(seller_id);
CREATE INDEX idx_customers_unique ON olist.customers(customer_unique_id);
CREATE INDEX idx_geo_zip ON olist.geolocation(geolocation_zip_code_prefix);
