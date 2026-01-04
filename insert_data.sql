/* =========================================================
   Olist (Brazilian E-Commerce Public Dataset) - ClickHouse
   Files (your truncated ones):
   olist_customers_dataset.csv
   olist_geolocation_dataset.csv
   olist_orders_dataset.csv
   olist_order_items_dataset.csv
   olist_order_payments_dataset.csv
   olist_order_reviews_dataset.csv
   olist_products_dataset.csv
   olist_sellers_dataset.csv
   product_category_name_translation.csv
   ========================================================= */

CREATE DATABASE IF NOT EXISTS olist;

-- Customers
DROP TABLE IF EXISTS olist.customers;
CREATE TABLE olist.customers
(
  customer_id             FixedString(32),
  customer_unique_id      FixedString(32),
  customer_zip_code_prefix UInt32,
  customer_city           LowCardinality(String),
  customer_state          LowCardinality(String)  -- 2-letter UF
)
ENGINE = MergeTree
ORDER BY (customer_id);

-- Geolocation (many rows per zip prefix)
DROP TABLE IF EXISTS olist.geolocation;
CREATE TABLE olist.geolocation
(
  geolocation_zip_code_prefix UInt32,
  geolocation_lat             Float64,
  geolocation_lng             Float64,
  geolocation_city            LowCardinality(String),
  geolocation_state           LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng);

-- Sellers
DROP TABLE IF EXISTS olist.sellers;
CREATE TABLE olist.sellers
(
  seller_id              FixedString(32),
  seller_zip_code_prefix UInt32,
  seller_city            LowCardinality(String),
  seller_state           LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY (seller_id);

-- Products
DROP TABLE IF EXISTS olist.products;
CREATE TABLE olist.products
(
  product_id                  FixedString(32),
  product_category_name       Nullable(String),
  product_name_lenght         Nullable(UInt16),
  product_description_lenght  Nullable(UInt16),
  product_photos_qty          Nullable(UInt16),
  product_weight_g            Nullable(UInt32),
  product_length_cm           Nullable(UInt16),
  product_height_cm           Nullable(UInt16),
  product_width_cm            Nullable(UInt16)
)
ENGINE = MergeTree
ORDER BY (product_id);

-- Category translation
DROP TABLE IF EXISTS olist.product_category_name_translation;
CREATE TABLE olist.product_category_name_translation
(
  product_category_name         String,
  product_category_name_english String
)
ENGINE = MergeTree
ORDER BY (product_category_name);

-- Orders
DROP TABLE IF EXISTS olist.orders;
CREATE TABLE olist.orders
(
  order_id                        FixedString(32),
  customer_id                     FixedString(32),
  order_status                    LowCardinality(String),
  order_purchase_timestamp        DateTime,
  order_approved_at               Nullable(DateTime),
  order_delivered_carrier_date    Nullable(DateTime),
  order_delivered_customer_date   Nullable(DateTime),
  order_estimated_delivery_date   Nullable(DateTime)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(order_purchase_timestamp)
ORDER BY (order_purchase_timestamp, order_id);

-- Order items (one order -> many items)
DROP TABLE IF EXISTS olist.order_items;
CREATE TABLE olist.order_items
(
  order_id             FixedString(32),
  order_item_id        UInt16,
  product_id           FixedString(32),
  seller_id            FixedString(32),
  shipping_limit_date  DateTime,
  price                Decimal(12, 2),
  freight_value        Decimal(12, 2)
)
ENGINE = MergeTree
ORDER BY (order_id, order_item_id);

-- Payments (one order -> multiple payment rows possible)
DROP TABLE IF EXISTS olist.order_payments;
CREATE TABLE olist.order_payments
(
  order_id               FixedString(32),
  payment_sequential     UInt16,
  payment_type           LowCardinality(String),
  payment_installments   UInt16,
  payment_value          Decimal(12, 2)
)
ENGINE = MergeTree
ORDER BY (order_id, payment_sequential);

-- Reviews
DROP TABLE IF EXISTS olist.order_reviews;
CREATE TABLE olist.order_reviews
(
  review_id                FixedString(32),
  order_id                 FixedString(32),
  review_score             UInt8,
  review_comment_title     Nullable(String),
  review_comment_message   Nullable(String),
  review_creation_date     Nullable(DateTime),
  review_answer_timestamp  Nullable(DateTime)
)
ENGINE = MergeTree
ORDER BY (review_id);


/* =========================
   LOAD (server-side file() table function)
   NOTE: file() reads from the ClickHouse SERVER filesystem.
   If you run ClickHouse locally, these paths work as-is.
   ========================= */

-- Recommended when CSVs have empty strings in nullable datetime/string fields
-- SETTINGS input_format_csv_empty_as_default=0;

INSERT INTO olist.customers
SELECT
  customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state
FROM file('olist_customers_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.geolocation
SELECT
  geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
FROM file('olist_geolocation_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.sellers
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM file('olist_sellers_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.products
SELECT
  product_id,
  NULLIF(product_category_name, '') AS product_category_name,
  product_name_lenght,
  product_description_lenght,
  product_photos_qty,
  product_weight_g,
  product_length_cm,
  product_height_cm,
  product_width_cm
FROM file('olist_products_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.product_category_name_translation
SELECT product_category_name, product_category_name_english
FROM file('product_category_name_translation.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.orders
SELECT
  order_id,
  customer_id,
  order_status,
  order_purchase_timestamp,
  NULLIF(order_approved_at, '')              AS order_approved_at,
  NULLIF(order_delivered_carrier_date, '')   AS order_delivered_carrier_date,
  NULLIF(order_delivered_customer_date, '')  AS order_delivered_customer_date,
  NULLIF(order_estimated_delivery_date, '')  AS order_estimated_delivery_date
FROM file('olist_orders_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.order_items
SELECT
  order_id,
  order_item_id,
  product_id,
  seller_id,
  shipping_limit_date,
  toDecimal32(price, 2)         AS price,
  toDecimal32(freight_value, 2) AS freight_value
FROM file('olist_order_items_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.order_payments
SELECT
  order_id,
  payment_sequential,
  payment_type,
  payment_installments,
  toDecimal32(payment_value, 2) AS payment_value
FROM file('olist_order_payments_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;

INSERT INTO olist.order_reviews
SELECT
  review_id,
  order_id,
  review_score,
  NULLIF(review_comment_title, '')    AS review_comment_title,
  NULLIF(review_comment_message, '')  AS review_comment_message,
  NULLIF(review_creation_date, '')    AS review_creation_date,
  NULLIF(review_answer_timestamp, '') AS review_answer_timestamp
FROM file('olist_order_reviews_dataset.csv', 'CSVWithNames')
SETTINGS input_format_csv_empty_as_default = 0;
