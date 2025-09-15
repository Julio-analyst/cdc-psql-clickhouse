-- Setup untuk orders saja dulu (sesuai connector config yang sebelumnya)
CREATE TABLE IF NOT EXISTS orders_kafka_json (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'dbserver1.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'LineAsString',
    kafka_row_delimiter = '\n',
    kafka_schema = '',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

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
            toDate(toDateTime(JSONExtractInt(raw_message, 'payload', 'before', 'order_date')))
        ELSE
            toDate(toDateTime(JSONExtractInt(raw_message, 'payload', 'after', 'order_date')))
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

CREATE VIEW IF NOT EXISTS cdc_operations_summary AS
SELECT 
    'orders' as table_name,
    operation,
    count(*) as count,
    max(_synced_at) as last_sync
FROM orders_final
GROUP BY operation;