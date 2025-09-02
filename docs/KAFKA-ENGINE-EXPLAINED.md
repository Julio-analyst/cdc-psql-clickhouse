# 🚀 ClickHouse Kafka Engine: Complete Guide

**Perfect for:** Developers, Data Engineers, and Technical Decision Makers who want to understand real-time data streaming with ClickHouse

## 📖 Table of Contents
- [What is Kafka Engine?](#what-is-kafka-engine)
- [Historical Context](#historical-context)
- [Why Use Kafka Engine?](#why-use-kafka-engine)
- [Core Functions & Features](#core-functions--features)
- [Implementation in CDC Flow](#implementation-in-cdc-flow)
- [Technical Deep Dive](#technical-deep-dive)
- [Performance Benefits](#performance-benefits)
- [Real-World Use Cases](#real-world-use-cases)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🎯 What is Kafka Engine?

**ClickHouse Kafka Engine** is a specialized table engine that enables ClickHouse to consume data directly from Apache Kafka topics in real-time. It acts as a native bridge between Kafka's streaming platform and ClickHouse's analytical database, eliminating the need for external ETL tools.

### Simple Analogy
Think of Kafka Engine as a **"smart pipe"** that:
- 🔄 Continuously listens to Kafka topics
- 📦 Automatically pulls new messages 
- 🔄 Transforms JSON data into structured format
- 💾 Feeds data directly into ClickHouse tables

---

## 📚 Historical Context

### The Evolution of Data Integration

#### **Before Kafka Engine (Traditional Approach)**
```
Data Source → Batch ETL Jobs → Data Warehouse
     ↓           ↓                    ↓
  Real-time    Hours/Days         Outdated Analytics
```

**Problems:**
- ❌ **High Latency**: Data available hours/days later
- ❌ **Complex Architecture**: Multiple tools and systems
- ❌ **Resource Intensive**: Heavy ETL processing
- ❌ **Data Loss Risk**: Batch failures = missing data

#### **After Kafka Engine (Modern Approach)**
```
Data Source → Kafka Stream → ClickHouse (Real-time)
     ↓           ↓                ↓
  Real-time   Seconds        Live Analytics
```

**Benefits:**
- ✅ **Ultra-Low Latency**: Data available in seconds
- ✅ **Simple Architecture**: Direct integration
- ✅ **Resource Efficient**: Streaming processing
- ✅ **Guaranteed Delivery**: No data loss

### Timeline of Development
- **2016**: ClickHouse open-sourced by Yandex
- **2018**: Kafka Engine introduced in ClickHouse
- **2020**: Enhanced with JSON processing capabilities
- **2022**: Production-ready with offset management
- **2025**: Widely adopted for real-time analytics

---

## 🎯 Why Use Kafka Engine?

### **1. Real-Time Analytics Requirements**
Modern businesses need **instant insights**:
- 📊 Live dashboards and monitoring
- 🚨 Real-time alerting and fraud detection
- 📈 Immediate business intelligence
- 🎯 Personalized user experiences

### **2. Simplified Architecture**
**Without Kafka Engine:**
```
PostgreSQL → Debezium → Kafka → ETL Tool → Batch Loader → ClickHouse
                                    ↓
                            Complex, error-prone pipeline
```

**With Kafka Engine:**
```
PostgreSQL → Debezium → Kafka → ClickHouse (Direct)
                                    ↓
                            Simple, reliable pipeline
```

### **3. Cost Efficiency**
- **Reduced Infrastructure**: No need for separate ETL systems
- **Lower Maintenance**: Fewer moving parts to manage
- **Resource Optimization**: Native integration = better performance

### **4. Data Consistency**
- **Exactly-Once Semantics**: Guarantees no duplicate data
- **Offset Management**: Automatic tracking of processed messages
- **Fault Tolerance**: Automatic recovery from failures

---

## ⚙️ Core Functions & Features

### **Primary Functions**

#### **1. Message Consumption**
```sql
-- Kafka Engine continuously polls topics
ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'my-topic'
```

#### **2. Data Transformation**
```sql
-- Automatic JSON parsing and type conversion
payload String  -- Raw JSON from Kafka
    ↓
Structured columns in target tables
```

#### **3. Stream Processing**
```sql
-- Real-time data processing via Materialized Views
CREATE MATERIALIZED VIEW real_time_view AS
SELECT 
    JSONExtract(...) -- Parse and transform
FROM kafka_table
```

### **Key Features**

| Feature | Description | Benefit |
|---------|-------------|---------|
| **Auto-Commit** | Automatic offset management | No manual tracking needed |
| **Parallel Processing** | Multiple consumers per topic | Higher throughput |
| **JSON Support** | Native JSON parsing functions | Easy data extraction |
| **Error Handling** | Built-in retry mechanisms | Reliable data ingestion |
| **Monitoring** | System tables for metrics | Easy troubleshooting |

---

## 🔄 Implementation in CDC Flow

### **Our CDC Architecture with Kafka Engine**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │    Apache        │    │   ClickHouse    │
│   (Source DB)   │───▶│    Kafka         │───▶│  (Analytics)    │
│  📊 OLTP Data   │    │ 🚀 Event Stream  │    │ 📈 OLAP Query   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
    Order Changes         JSON Events            Real-time Tables
```

### **Step-by-Step Implementation**

#### **Step 1: Kafka Engine Table (Raw Data)**
```sql
-- Create Kafka Engine table to consume raw events
CREATE TABLE orders_kafka_json (
    payload String  -- Complete JSON message as string
) ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1,
    kafka_row_delimiter = '\n',
    kafka_commit_every_batch = 1,
    kafka_thread_per_consumer = 1;
```

#### **Step 2: Target Table (Structured Data)**
```sql
-- Create final table with proper schema
CREATE TABLE orders_final (
    order_id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt32,
    product_id UInt32,
    operation_type String,  -- INSERT, UPDATE, DELETE
    _synced_at DateTime DEFAULT now(),
    _partition_date Date DEFAULT today()
) ENGINE = MergeTree()
PARTITION BY _partition_date
ORDER BY (order_id, _synced_at)
SETTINGS index_granularity = 8192;
```

#### **Step 3: Materialized View (Real-time Transformation)**
```sql
-- Create materialized view for real-time processing
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    -- Extract data from Debezium JSON structure
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'id') as order_id,
    toDate(JSONExtractString(JSONExtractString(payload, 'after'), 'order_date')) as order_date,
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'purchaser') as purchaser,
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'quantity') as quantity,
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'product_id') as product_id,
    JSONExtractString(payload, 'op') as operation_type,
    now() as _synced_at,
    today() as _partition_date
FROM orders_kafka_json
WHERE JSONExtractString(payload, 'op') IN ('c', 'u', 'r'); -- Only capture INSERT, UPDATE, READ
```

### **Data Flow Through Kafka Engine**

#### **1. PostgreSQL Event Generation**
```sql
-- Example: New order inserted in PostgreSQL
INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id)
VALUES ('2025-09-03', 1001, 5, 102);
```

#### **2. Debezium Event Creation**
```json
{
  "before": null,
  "after": {
    "id": 10001,
    "order_date": "2025-09-03",
    "purchaser": 1001,
    "quantity": 5,
    "product_id": 102,
    "created_at": "2025-09-03T10:30:00Z"
  },
  "source": {
    "version": "2.6.0.Final",
    "connector": "postgresql",
    "name": "postgres-server",
    "ts_ms": 1725356200000,
    "snapshot": "false",
    "db": "inventory",
    "schema": "inventory",
    "table": "orders",
    "txId": 493,
    "lsn": 24023928
  },
  "op": "c",  // CREATE operation
  "ts_ms": 1725356200454
}
```

#### **3. Kafka Engine Consumption**
```
Kafka Engine automatically:
1. 🔍 Polls the topic every few milliseconds
2. 📥 Receives the JSON message
3. 💾 Stores it in orders_kafka_json.payload
4. ⚡ Triggers the materialized view
```

#### **4. Real-time Transformation**
```sql
-- Materialized view immediately processes:
SELECT
    10001 as order_id,           -- Extracted from JSON
    '2025-09-03' as order_date,  -- Parsed and converted
    1001 as purchaser,           -- Type converted
    5 as quantity,               -- Type converted
    102 as product_id,           -- Type converted
    'c' as operation_type,       -- Operation type
    now() as _synced_at         -- Timestamp added
-- Result: Structured data in orders_final table
```

#### **5. Query-Ready Data**
```sql
-- Data immediately available for analytics
SELECT 
    order_date,
    COUNT(*) as daily_orders,
    SUM(quantity) as total_items
FROM orders_final 
WHERE order_date = today()
GROUP BY order_date;
```

---

## 🔧 Technical Deep Dive

### **Kafka Engine Configuration Parameters**

| Parameter | Purpose | Example | Impact |
|-----------|---------|---------|---------|
| `kafka_broker_list` | Kafka server addresses | `'kafka:9092'` | Connection endpoint |
| `kafka_topic_list` | Topics to consume | `'topic1,topic2'` | Data sources |
| `kafka_group_name` | Consumer group ID | `'clickhouse_group'` | Offset management |
| `kafka_format` | Message format | `'JSONAsString'` | Parsing method |
| `kafka_num_consumers` | Parallel consumers | `1` or `4` | Throughput control |
| `kafka_commit_every_batch` | Offset commit frequency | `1` | Reliability vs performance |

### **Internal Architecture**

```
ClickHouse Kafka Engine Architecture:

┌─────────────────────────────────────────────────────────────┐
│                    ClickHouse Server                        │
│                                                             │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │  Kafka Engine   │    │ Materialized View │              │
│  │     Table       │───▶│    Processing     │─────┐        │
│  │                 │    │                  │     │        │
│  └─────────────────┘    └──────────────────┘     │        │
│           │                                       │        │
│           ▼                                       ▼        │
│  ┌─────────────────┐                    ┌─────────────────┐│
│  │ Kafka Consumer  │                    │  Target Table   ││
│  │   Background    │                    │  (MergeTree)    ││
│  │     Thread      │                    │                 ││
│  └─────────────────┘                    └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────┐
│  Apache Kafka   │
│     Cluster     │
└─────────────────┘
```

### **Memory Management**
```yaml
# Kafka Engine memory usage:
Consumer Buffer: 64MB per consumer (default)
Parse Buffer: 16MB for JSON processing
Offset Storage: Minimal (few KB)
Background Thread: 1 thread per table

# Total Memory = (64MB × num_consumers) + 16MB + overhead
```

### **Performance Characteristics**

| Metric | Typical Value | Optimal Range |
|--------|--------------|---------------|
| **Latency** | 100-500ms | < 1 second |
| **Throughput** | 10K-100K msg/sec | Depends on JSON complexity |
| **Memory Usage** | 64-256MB | Per Kafka table |
| **CPU Usage** | 5-15% | Single core per consumer |

---

## 📊 Performance Benefits

### **Latency Comparison**

| Method | End-to-End Latency | Use Case |
|--------|-------------------|----------|
| **Batch ETL** | 1-24 hours | Historical reporting |
| **Mini-batch** | 5-15 minutes | Near real-time |
| **Kafka Engine** | 1-10 seconds | Real-time analytics |
| **Direct Insert** | < 1 second | Transactional systems |

### **Resource Efficiency**

#### **Traditional Architecture**
```
PostgreSQL → ETL Server → Batch Files → ClickHouse
     ↓            ↓            ↓           ↓
  100% CPU    200% CPU     Disk I/O    100% CPU
              (Peak)       (Storage)   (Load spikes)

Total: 400% CPU + Storage overhead
```

#### **Kafka Engine Architecture**
```
PostgreSQL → Kafka → ClickHouse (Streaming)
     ↓         ↓          ↓
   5% CPU   10% CPU   15% CPU

Total: 30% CPU (continuous, predictable load)
```

### **Scalability Benefits**

| Aspect | Traditional | Kafka Engine | Improvement |
|--------|------------|--------------|-------------|
| **Horizontal Scale** | Complex | Simple partition increase | 5x easier |
| **Processing Power** | Peak-based sizing | Steady-state sizing | 60% less resources |
| **Failure Recovery** | Manual restart | Automatic resumption | 99.9% uptime |
| **Data Freshness** | Hours old | Seconds old | 1000x faster |

---

## 🌍 Real-World Use Cases

### **1. E-commerce Real-time Analytics**
```sql
-- Real-time sales dashboard
SELECT 
    toStartOfHour(order_date) as hour,
    COUNT(*) as orders_count,
    SUM(quantity * price) as revenue,
    AVG(quantity) as avg_order_size
FROM orders_final o
JOIN products_final p ON o.product_id = p.product_id
WHERE order_date >= today()
GROUP BY hour
ORDER BY hour DESC;

-- Result: Live sales metrics updated every second
```

### **2. Fraud Detection System**
```sql
-- Detect suspicious activity patterns
SELECT 
    purchaser,
    COUNT(*) as order_count,
    SUM(quantity) as total_items,
    countDistinct(product_id) as unique_products
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 1 HOUR
GROUP BY purchaser
HAVING order_count > 10 OR total_items > 100;

-- Result: Real-time fraud alerts
```

### **3. Inventory Management**
```sql
-- Live inventory tracking
SELECT 
    product_id,
    initial_stock,
    SUM(CASE WHEN operation_type = 'c' THEN -quantity ELSE 0 END) as sold,
    initial_stock + SUM(CASE WHEN operation_type = 'c' THEN -quantity ELSE 0 END) as current_stock
FROM orders_final o
RIGHT JOIN (
    SELECT product_id, stock as initial_stock 
    FROM products_final
) p USING product_id
GROUP BY product_id, initial_stock
HAVING current_stock < 10;

-- Result: Low stock alerts in real-time
```

### **4. Customer Behavior Analytics**
```sql
-- Real-time customer journey
SELECT 
    purchaser,
    groupArray(product_id) as purchase_sequence,
    COUNT(*) as total_orders,
    max(_synced_at) as last_activity
FROM orders_final 
WHERE _synced_at >= today()
GROUP BY purchaser
ORDER BY last_activity DESC;

-- Result: Live customer behavior insights
```

---

## 💡 Best Practices

### **1. Table Design**
```sql
-- ✅ DO: Use appropriate data types
CREATE TABLE orders_kafka_json (
    payload String  -- Store raw JSON for flexibility
) ENGINE = Kafka;

-- ✅ DO: Design efficient target schema
CREATE TABLE orders_final (
    order_id UInt32,           -- Use UInt for IDs
    order_date Date,           -- Date type for date fields
    amount Decimal(10,2),      -- Decimal for money
    _synced_at DateTime,       -- Always include sync timestamp
    _partition_date Date       -- Partition key for performance
) ENGINE = MergeTree()
PARTITION BY _partition_date   -- Partition for better performance
ORDER BY (order_id, _synced_at);
```

### **2. Consumer Configuration**
```sql
-- ✅ DO: Configure for reliability
SETTINGS 
    kafka_commit_every_batch = 1,      -- Commit after each batch
    kafka_max_block_size = 65536,      -- Reasonable batch size
    kafka_poll_timeout_ms = 5000,      -- Good polling frequency
    kafka_flush_interval_ms = 7500;    -- Regular flushing

-- ❌ DON'T: Over-optimize for throughput at cost of reliability
SETTINGS 
    kafka_commit_every_batch = 0,      -- Risk of data loss
    kafka_max_block_size = 1048576;    -- Too large, memory issues
```

### **3. Monitoring Setup**
```sql
-- ✅ DO: Monitor consumer lag
SELECT 
    database,
    table,
    name,
    consumer_id,
    assignments.topic,
    assignments.partition_id,
    assignments.current_offset,
    assignments.high_water_mark,
    assignments.high_water_mark - assignments.current_offset as lag
FROM system.kafka_consumers
ARRAY JOIN assignments;

-- ✅ DO: Monitor table sizes
SELECT 
    table,
    sum(rows) as total_rows,
    sum(bytes_on_disk) as size_bytes
FROM system.parts 
WHERE table LIKE '%kafka%'
GROUP BY table;
```

### **4. Error Handling**
```sql
-- ✅ DO: Handle malformed JSON gracefully
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'id') as order_id,
    -- Add validation
    if(isValidJSON(payload), 
       toDate(JSONExtractString(JSONExtractString(payload, 'after'), 'order_date')), 
       toDate('1900-01-01')) as order_date,
    JSONExtractString(payload, 'op') as operation_type
FROM orders_kafka_json
WHERE isValidJSON(payload)  -- Filter invalid JSON
  AND JSONExtractString(payload, 'op') IN ('c', 'u', 'r');
```

### **5. Performance Optimization**
```sql
-- ✅ DO: Use proper partitioning
PARTITION BY toYYYYMM(order_date)  -- Monthly partitions
ORDER BY (customer_id, order_date)  -- Efficient sorting key

-- ✅ DO: Index frequently queried columns
ALTER TABLE orders_final ADD INDEX idx_customer customer_id TYPE bloom_filter GRANULARITY 1;

-- ✅ DO: Use compression for large tables
SETTINGS storage_policy = 'default'  -- Use compression
```

---

## 🔍 Troubleshooting

### **Common Issues & Solutions**

#### **1. Consumer Lag Issues**
```bash
# Problem: High consumer lag
# Symptoms: Delayed data, increasing lag metrics

# Solution 1: Increase consumers
ALTER TABLE orders_kafka_json MODIFY SETTING kafka_num_consumers = 4;

# Solution 2: Optimize batch size
ALTER TABLE orders_kafka_json MODIFY SETTING kafka_max_block_size = 131072;

# Solution 3: Check resource usage
SELECT * FROM system.processes WHERE query LIKE '%kafka%';
```

#### **2. JSON Parsing Errors**
```sql
-- Problem: Invalid JSON causing view failures
-- Solution: Add validation and error logging

CREATE TABLE json_errors (
    payload String,
    error_time DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY error_time;

CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    JSONExtractUInt(JSONExtractString(payload, 'after'), 'id') as order_id,
    -- ... other fields
FROM orders_kafka_json
WHERE isValidJSON(payload);

-- Capture errors separately
CREATE MATERIALIZED VIEW error_mv TO json_errors AS
SELECT payload
FROM orders_kafka_json
WHERE NOT isValidJSON(payload);
```

#### **3. Memory Issues**
```sql
-- Problem: High memory usage
-- Symptoms: OOM errors, slow performance

-- Solution 1: Reduce batch size
ALTER TABLE orders_kafka_json MODIFY SETTING kafka_max_block_size = 32768;

-- Solution 2: Increase flush frequency
ALTER TABLE orders_kafka_json MODIFY SETTING kafka_flush_interval_ms = 3000;

-- Solution 3: Monitor memory usage
SELECT 
    name,
    value
FROM system.asynchronous_metrics 
WHERE name LIKE '%Memory%';
```

#### **4. Connection Issues**
```bash
# Problem: Cannot connect to Kafka
# Symptoms: Consumer not starting, connection errors

# Check Kafka connectivity
docker exec clickhouse-server wget -qO- http://kafka:9092 2>&1

# Check topic exists
docker exec kafka-tools kafka-topics --list --bootstrap-server kafka:9092

# Verify consumer group
docker exec kafka-tools kafka-consumer-groups --bootstrap-server kafka:9092 --list
```

### **Debugging Queries**

#### **Consumer Status**
```sql
-- Check all Kafka consumers
SELECT 
    database,
    table,
    consumer_id,
    status,
    assignments.topic,
    assignments.partition_id,
    assignments.current_offset,
    assignments.high_water_mark
FROM system.kafka_consumers
ARRAY JOIN assignments;
```

#### **Performance Metrics**
```sql
-- Check processing rates
SELECT 
    table,
    sum(rows) as total_rows,
    max(modification_time) as last_insert,
    now() - max(modification_time) as seconds_behind
FROM system.parts 
WHERE table LIKE '%kafka%'
GROUP BY table;
```

#### **Error Monitoring**
```sql
-- Check for processing errors
SELECT 
    event_time,
    thread_name,
    message
FROM system.text_log 
WHERE logger_name LIKE '%Kafka%'
  AND level = 'Error'
ORDER BY event_time DESC
LIMIT 10;
```

---

## 🎓 Learning Resources

### **Documentation**
- [ClickHouse Kafka Engine Official Docs](https://clickhouse.com/docs/en/engines/table-engines/integrations/kafka/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Debezium PostgreSQL Connector](https://debezium.io/documentation/reference/connectors/postgresql.html)

### **Advanced Topics**
- [Kafka Engine Partitioning Strategies](https://clickhouse.com/docs/en/engines/table-engines/integrations/kafka/#kafka-partitioning)
- [JSON Processing Functions](https://clickhouse.com/docs/en/sql-reference/functions/json-functions/)
- [Materialized Views Best Practices](https://clickhouse.com/docs/en/guides/developer/cascading-materialized-views/)

### **Monitoring Tools**
- [ClickHouse System Tables](https://clickhouse.com/docs/en/operations/system-tables/)
- [Kafka Consumer Monitoring](https://kafka.apache.org/documentation/#monitoring)
- [Grafana ClickHouse Integration](https://grafana.com/docs/grafana/latest/datasources/clickhouse/)

---

## 📝 Summary

**ClickHouse Kafka Engine** is a game-changing technology that enables:

✅ **Real-time Analytics**: Sub-second data availability  
✅ **Simplified Architecture**: Direct Kafka-to-ClickHouse integration  
✅ **High Performance**: Native streaming processing  
✅ **Reliability**: Exactly-once semantics and fault tolerance  
✅ **Scalability**: Horizontal scaling through partitioning  
✅ **Cost Efficiency**: Reduced infrastructure complexity  

By implementing Kafka Engine in your CDC pipeline, you transform from **batch-based delays** to **real-time insights**, enabling modern data-driven decision making.

---

## 🔗 Related Documentation
- 🏗️ [Technical Architecture](ARCHITECTURE.md) - Complete system design
- ⚡ [Quick Start Guide](SCRIPTS-QUICK-START.md) - Get it running first  
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Fix common issues
- ⚙️ [Configuration Guide](CONFIGURATION.md) - Advanced setup options

---
🏠 [← Back to Main README](../README.md) | 🏗️ [Architecture](ARCHITECTURE.md) | 🔧 [Troubleshooting →](TROUBLESHOOTING.md)
