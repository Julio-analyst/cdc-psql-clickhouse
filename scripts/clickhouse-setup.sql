-- ClickHouse Complete Setup for CDC
-- This script creates Kafka Engine tables and materialized views for real-time CDC

-- ===========================
-- ORDERS TABLE SETUP
-- ===========================

-- 1. Create Kafka Engine table for raw JSON messages from orders topic
CREATE TABLE IF NOT EXISTS orders_kafka_json (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'LineAsString',
    kafka_row_delimiter = '\n',
    kafka_schema = '',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- 2. Create final MergeTree table for orders
CREATE TABLE IF NOT EXISTS orders_final (
    id Int32,
    order_date Date,
    purchaser Int32,
    quantity Int32,
    product_id Int32,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, _synced_at)
PARTITION BY toYYYYMM(order_date);

-- 3. Create materialized view for orders (handles all CDC operations)
CREATE MATERIALIZED VIEW IF NOT EXISTS orders_mv TO orders_final AS
SELECT
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'id')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'id')
    END as id,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            toDate(JSONExtractInt(raw_message, 'payload', 'before', 'order_date') + toDate('1970-01-01'))
        ELSE
            toDate(JSONExtractInt(raw_message, 'payload', 'after', 'order_date') + toDate('1970-01-01'))
    END as order_date,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'purchaser')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'purchaser')
    END as purchaser,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'quantity')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'quantity')
    END as quantity,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'product_id')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'product_id')
    END as product_id,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM orders_kafka_json
WHERE JSONExtractString(raw_message, 'payload', 'op') IN ('c', 'r', 'u', 'd');

-- ===========================
-- CUSTOMERS TABLE SETUP
-- ===========================

-- 1. Create Kafka Engine table for customers
CREATE TABLE IF NOT EXISTS customers_kafka_json (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.customers',
    kafka_group_name = 'clickhouse_customers_group',
    kafka_format = 'LineAsString',
    kafka_row_delimiter = '\n',
    kafka_schema = '',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- 2. Create final MergeTree table for customers
CREATE TABLE IF NOT EXISTS customers_final (
    id Int32,
    first_name String,
    last_name String,
    email String,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, _synced_at);

-- 3. Create materialized view for customers
CREATE MATERIALIZED VIEW IF NOT EXISTS customers_mv TO customers_final AS
SELECT
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'id')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'id')
    END as id,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractString(raw_message, 'payload', 'before', 'first_name')
        ELSE
            JSONExtractString(raw_message, 'payload', 'after', 'first_name')
    END as first_name,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractString(raw_message, 'payload', 'before', 'last_name')
        ELSE
            JSONExtractString(raw_message, 'payload', 'after', 'last_name')
    END as last_name,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractString(raw_message, 'payload', 'before', 'email')
        ELSE
            JSONExtractString(raw_message, 'payload', 'after', 'email')
    END as email,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM customers_kafka_json
WHERE JSONExtractString(raw_message, 'payload', 'op') IN ('c', 'r', 'u', 'd');

-- ===========================
-- PRODUCTS TABLE SETUP
-- ===========================

-- 1. Create Kafka Engine table for products
CREATE TABLE IF NOT EXISTS products_kafka_json (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.products',
    kafka_group_name = 'clickhouse_products_group',
    kafka_format = 'LineAsString',
    kafka_row_delimiter = '\n',
    kafka_schema = '',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- 2. Create final MergeTree table for products
CREATE TABLE IF NOT EXISTS products_final (
    id Int32,
    name String,
    description String,
    weight Float64,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, _synced_at);

-- 3. Create materialized view for products
CREATE MATERIALIZED VIEW IF NOT EXISTS products_mv TO products_final AS
SELECT
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractInt(raw_message, 'payload', 'before', 'id')
        ELSE
            JSONExtractInt(raw_message, 'payload', 'after', 'id')
    END as id,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractString(raw_message, 'payload', 'before', 'name')
        ELSE
            JSONExtractString(raw_message, 'payload', 'after', 'name')
    END as name,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractString(raw_message, 'payload', 'before', 'description')
        ELSE
            JSONExtractString(raw_message, 'payload', 'after', 'description')
    END as description,
    CASE 
        WHEN JSONExtractString(raw_message, 'payload', 'op') = 'd' THEN
            JSONExtractFloat(raw_message, 'payload', 'before', 'weight')
        ELSE
            JSONExtractFloat(raw_message, 'payload', 'after', 'weight')
    END as weight,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM products_kafka_json
WHERE JSONExtractString(raw_message, 'payload', 'op') IN ('c', 'r', 'u', 'd');

-- ===========================
-- UTILITY VIEWS AND FUNCTIONS
-- ===========================

-- Create view for monitoring all CDC operations
CREATE VIEW IF NOT EXISTS cdc_operations_summary AS
SELECT 
    'orders' as table_name,
    operation,
    count(*) as count,
    max(_synced_at) as last_sync
FROM orders_final
GROUP BY operation

UNION ALL

SELECT 
    'customers' as table_name,
    operation,
    count(*) as count,
    max(_synced_at) as last_sync
FROM customers_final
GROUP BY operation

UNION ALL

SELECT 
    'products' as table_name,
    operation,
    count(*) as count,
    max(_synced_at) as last_sync
FROM products_final
GROUP BY operation

ORDER BY table_name, operation;
