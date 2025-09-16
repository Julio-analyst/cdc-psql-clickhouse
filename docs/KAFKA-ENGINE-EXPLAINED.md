# 🚀 ClickHouse Kafka Engine Explained

Essential guide to understanding and using ClickHouse Kafka Engine for real-time data streaming.

## 🎯 What is Kafka Engine?

**ClickHouse Kafka Engine** is a table engine that enables ClickHouse to consume data directly from Kafka topics in real-time, acting as a bridge between Kafka streaming and ClickHouse analytics.

### Simple Concept
```
Kafka Topic → Kafka Engine Table → Materialized View → MergeTree Table
     ↓              ↓                      ↓               ↓
  JSON Data    Stream Buffer        Data Transform    Final Storage
```

## 🔄 How It Works

### Data Flow Process
1. **Kafka Engine** continuously polls Kafka topics
2. **Messages** are stored temporarily in the engine table
3. **Materialized View** processes and transforms data
4. **Final data** is inserted into MergeTree tables

### Real Example
```sql
-- 1. Kafka Engine (streaming input)
CREATE TABLE orders_queue (
    raw_data String
) ENGINE = Kafka('kafka:9092', 'postgres-server.inventory.orders', 'clickhouse-group')
SETTINGS kafka_format = 'JSONAsString';

-- 2. MergeTree table (final storage)
CREATE TABLE orders_final (
    id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt16,
    product_id UInt32,
    operation String,
    _synced_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (order_date, id);

-- 3. Materialized View (real-time transformation)
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    JSONExtractUInt(raw_data, 'after', 'id') as id,
    toDate(JSONExtractUInt(raw_data, 'after', 'order_date') + toDate('1970-01-01')) as order_date,
    JSONExtractUInt(raw_data, 'after', 'purchaser') as purchaser,
    JSONExtractUInt(raw_data, 'after', 'quantity') as quantity,
    JSONExtractUInt(raw_data, 'after', 'product_id') as product_id,
    JSONExtractString(raw_data, 'op') as operation
FROM orders_queue
WHERE length(JSONExtractString(raw_data, 'after')) > 0;
```

## ⚡ Key Benefits

### Before Kafka Engine (Traditional ETL)
```
Kafka → External Consumer → ETL Process → Database
  ↓           ↓                ↓            ↓
Complex     Extra Tools     Batch Jobs   Delayed Data
```

### With Kafka Engine (Direct Integration)
```
Kafka → ClickHouse Kafka Engine → Analytics
  ↓              ↓                    ↓
Simple      Built-in Feature      Real-time
```

### Advantages
- **🚀 Real-time Processing**: No batch delays
- **🔧 Built-in Feature**: No external tools needed
- **📈 High Performance**: Parallel processing
- **🛠️ Easy Setup**: Simple SQL configuration
- **🔄 Auto-Recovery**: Built-in fault tolerance

## ⚙️ Configuration Options

### Basic Settings
```sql
ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'topic-name',
    kafka_group_name = 'consumer-group',
    kafka_format = 'JSONAsString';
```

### Performance Settings
```sql
SETTINGS 
    kafka_num_consumers = 3,           -- Parallel consumers
    kafka_max_block_size = 1048576,    -- 1MB blocks
    kafka_flush_interval_ms = 7500,    -- 7.5 seconds
    kafka_poll_timeout_ms = 5000,      -- 5 seconds
    kafka_skip_broken_messages = 1000; -- Skip errors
```

### Common Formats
| Format | Use Case | Example |
|--------|----------|---------|
| `JSONAsString` | CDC data, complex JSON | Debezium events |
| `JSONEachRow` | Simple JSON objects | API data |
| `CSV` | Simple delimited data | Log files |
| `Avro` | Schema registry data | Confluent ecosystem |

## 📊 Monitoring Kafka Engine

### System Tables for Monitoring
```sql
-- Check consumer status
SELECT * FROM system.kafka_consumers;

-- View current assignments
SELECT 
    table,
    assignments.topic[1] as topic,
    assignments.partition_id[1] as partition,
    assignments.current_offset[1] as current_offset,
    assignments.high_water_mark[1] as high_water_mark,
    assignments.high_water_mark[1] - assignments.current_offset[1] as lag
FROM system.kafka_consumers
ARRAY JOIN assignments;

-- Monitor table sizes
SELECT 
    name,
    total_rows,
    total_bytes
FROM system.tables 
WHERE engine = 'Kafka';
```

### Key Metrics to Watch
- **Consumer Lag**: Difference between high water mark and current offset
- **Processing Rate**: Messages processed per second
- **Error Rate**: Failed message count
- **Memory Usage**: Kafka table memory consumption

## 🔧 Common Patterns

### Pattern 1: CDC Events (Debezium)
```sql
-- For CDC events with before/after structure
CREATE MATERIALIZED VIEW cdc_mv TO final_table AS
SELECT
    JSONExtractUInt(raw_data, 'payload', 'after', 'id') as id,
    JSONExtractString(raw_data, 'payload', 'op') as operation,
    toDateTime(JSONExtractUInt(raw_data, 'payload', 'ts_ms') / 1000) as event_time
FROM kafka_queue
WHERE JSONExtractString(raw_data, 'payload', 'op') IN ('c', 'u', 'd');
```

### Pattern 2: Simple JSON Events
```sql
-- For direct JSON objects
CREATE MATERIALIZED VIEW json_mv TO final_table AS
SELECT
    JSONExtractUInt(raw_data, 'user_id') as user_id,
    JSONExtractString(raw_data, 'event_type') as event_type,
    JSONExtractUInt(raw_data, 'timestamp') as timestamp
FROM kafka_queue;
```

### Pattern 3: Error Handling
```sql
-- Separate error table for failed records
CREATE TABLE error_records (
    raw_data String,
    error_reason String,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY created_at;

-- Materialized view with error handling
CREATE MATERIALIZED VIEW safe_mv TO final_table AS
SELECT
    tryJSONExtractUInt(raw_data, 'id') as id,
    tryJSONExtractString(raw_data, 'name') as name
FROM kafka_queue
WHERE isNotNull(tryJSONExtractUInt(raw_data, 'id'));
```

## 🚨 Troubleshooting

### Issue 1: No Data Flowing
**Check:**
```sql
-- Verify Kafka table is consuming
SELECT count(*) FROM kafka_table_name;

-- Check system consumers
SELECT * FROM system.kafka_consumers;
```

**Solutions:**
- Restart ClickHouse: `docker-compose restart clickhouse`
- Check topic exists in Kafka
- Verify consumer group permissions

### Issue 2: High Consumer Lag
**Check:**
```sql
-- Monitor lag
SELECT 
    assignments.high_water_mark[1] - assignments.current_offset[1] as lag
FROM system.kafka_consumers 
ARRAY JOIN assignments;
```

**Solutions:**
- Increase `kafka_num_consumers`
- Optimize materialized view queries
- Increase `kafka_max_block_size`

### Issue 3: JSON Parsing Errors
**Check:**
```sql
-- Test JSON extraction
SELECT 
    raw_data,
    isValidJSON(raw_data) as valid_json,
    JSONExtract(raw_data, 'field') as extracted
FROM kafka_table_name 
LIMIT 10;
```

**Solutions:**
- Use `try` functions: `tryJSONExtract()`
- Add error handling in materialized views
- Set `kafka_skip_broken_messages`

## 💡 Best Practices

### Performance Optimization
1. **Use appropriate block sizes**: `kafka_max_block_size = 1048576`
2. **Set parallel consumers**: `kafka_num_consumers = 3`
3. **Optimize flush interval**: `kafka_flush_interval_ms = 7500`
4. **Use indexed columns** in ORDER BY clause

### Data Quality
1. **Validate JSON** before processing
2. **Handle missing fields** gracefully
3. **Use error tables** for failed records
4. **Monitor consumer lag** regularly

### Operational
1. **Monitor system tables** for health checks
2. **Set up alerts** for high lag or errors
3. **Use descriptive names** for tables and views
4. **Document schema changes** and migrations

### Example Production Setup
```sql
-- Production-ready Kafka Engine
CREATE TABLE production_events_queue (
    raw_event String
) ENGINE = Kafka('kafka-cluster:9092', 'production.events', 'clickhouse-prod-group')
SETTINGS 
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 5,
    kafka_max_block_size = 2097152,      -- 2MB
    kafka_flush_interval_ms = 5000,       -- 5 seconds
    kafka_poll_timeout_ms = 3000,         -- 3 seconds
    kafka_skip_broken_messages = 100,     -- Skip errors
    kafka_commit_every_batch_consumed = 1; -- Commit frequently
```

---

## Related Documentation
- 🏗️ **[Architecture](ARCHITECTURE.md)** - System overview
- ⚙️ **[Configuration](CONFIGURATION.md)** - Service configurations
- � **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Implementation guide
- �🔧 **[Database Connection Troubleshooting](DATABASE-CONNECTION-TROUBLESHOOTING.md)** - Connection issues
- 📊 **[DBeaver Setup](DBEAVER-SETUP.md)** - Database GUI setup