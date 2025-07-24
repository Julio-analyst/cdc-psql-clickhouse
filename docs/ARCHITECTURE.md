# 🏗️ Technical Architecture


## System Overview

### High-Level Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │    Apache        │    │   ClickHouse    │
│   (Source DB)   │───▶│    Kafka         │───▶│  (Analytics)    │
│                 │    │   + Debezium     │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
     OLTP System          Event Streaming         OLAP System
```

### Detailed Component Flow
```
PostgreSQL WAL → Debezium Connector → Kafka Topics → ClickHouse Kafka Engine → MergeTree Tables
      ↓              ↓                    ↓              ↓                      ↓
   Data Changes   JSON Events        Partitioned      Real-time            Optimized
   (Binary)       (Structured)        Streams        Consumption           Storage
```
## Data Flow Architecture

### Step-by-Step Process
1. **Change Detection**: PostgreSQL writes operations to WAL
2. **Event Capture**: Debezium reads WAL and creates JSON events
3. **Event Publishing**: Events sent to Kafka topics (partitioned by table)
4. **Event Consumption**: ClickHouse Kafka Engine consumes events
5. **Data Transformation**: Materialized views parse JSON to structured data
6. **Storage**: Final data stored in MergeTree tables for fast analytics

### Event Structure
```json
{
  "before": null,
  "after": {
    "id": 10001,
    "order_date": "2025-07-21",
    "purchaser": 1001,
    "quantity": 5,
    "product_id": 102
  },
  "source": {
    "version": "1.9.7.Final",
    "connector": "postgresql",
    "name": "postgres-server",
    "ts_ms": 1703174439000,
    "snapshot": "false",
    "db": "inventory",
    "sequence": "[\"24023928\",\"24023928\"]",
    "schema": "inventory",
    "table": "orders",
    "txId": 493,
    "lsn": 24023928,
    "xmin": null
  },
  "op": "c",
  "ts_ms": 1703174439454,
  "transaction": null
}
```

## Service Architecture

### Container Services
| Service | Purpose | Port | Dependencies |
|---------|---------|------|-------------|
| **PostgreSQL** | Source OLTP database | 5432 | None |
| **Zookeeper** | Kafka coordination | 2181 | None |
| **Kafka** | Event streaming | 9092 | Zookeeper |
| **Kafka Connect** | Debezium runtime | 8083 | Kafka |
| **ClickHouse Keeper** | ClickHouse coordination | 9181 | None |
| **ClickHouse** | Analytics database | 8123, 9000 | ClickHouse Keeper |
| **Kafdrop** | Kafka Web UI | 9001 | Kafka |


## Data Models

### PostgreSQL Schema (Source)
```sql
-- Orders table
CREATE TABLE inventory.orders (
    id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL,
    purchaser INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Customers table  
CREATE TABLE inventory.customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Products table
CREATE TABLE inventory.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);
```

### ClickHouse Schema (Target)
```sql
-- Kafka Engine (Raw Events)
CREATE TABLE orders_kafka_json (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'LineAsString',
    kafka_skip_broken_messages = 1;

-- Final Table (Processed Data)
CREATE TABLE orders_final (
    id Int32,
    order_date Date,
    purchaser Int32,
    quantity Int32,
    product_id Int32,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (purchaser, id)
PARTITION BY toYYYYMM(order_date);

-- Materialized View (Real-time Processing)
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT 
    JSONExtractInt(raw_message, 'payload', 'after', 'id') as id,
    toDate(JSONExtractString(raw_message, 'payload', 'after', 'order_date')) as order_date,
    JSONExtractInt(raw_message, 'payload', 'after', 'purchaser') as purchaser,
    JSONExtractInt(raw_message, 'payload', 'after', 'quantity') as quantity,
    JSONExtractInt(raw_message, 'payload', 'after', 'product_id') as product_id,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM orders_kafka_json;
```

### Resource Requirements
```yaml
# Minimum Requirements
Memory: 8GB RAM
CPU: 4 cores
Storage: 50GB SSD
Network: 1Gbps

# Recommended Production
Memory: 16GB+ RAM
CPU: 8+ cores  
Storage: 200GB+ NVMe SSD
Network: 10Gbps
```

## Monitoring & Observability

### Key Metrics
- **Kafka Lag**: Consumer group lag monitoring
- **Throughput**: Messages/second processed
- **Latency**: End-to-end processing time
- **Error Rate**: Failed message percentage
- **Resource Usage**: CPU, Memory, Disk utilization

### Monitoring Tools
- **Kafdrop**: Kafka topics and consumers
- **ClickHouse System Tables**: Query performance
- **Docker Stats**: Container resource usage
- **Custom Scripts**: CDC operation monitoring

## Security Architecture

### Network Security
```yaml
# Network isolation
networks:
  cdcnet:
    driver: bridge
    internal: true  # No external internet access
    
# Service communication
services:
  postgres-source:
    networks:
      - cdcnet
  kafka:
    networks: 
      - cdcnet
  clickhouse:
    networks:
      - cdcnet
```

## Security Architecture

### Network Security
```yaml
# Network isolation
networks:
  cdcnet:
    driver: bridge
    internal: true  # No external internet access
    
# Service communication
services:
  postgres-source:
    networks:
      - cdcnet
  kafka:
    networks: 
      - cdcnet
  clickhouse:
    networks:
      - cdcnet
```
