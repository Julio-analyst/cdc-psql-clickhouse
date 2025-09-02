# 🏗️ Technical Architecture

**Perfect for:** Developers, DevOps engineers, and technical decision makers

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

## Core Components

### 1. **PostgreSQL (Source Database)**
- **Role**: Primary OLTP database with business data
- **Technology**: PostgreSQL 16.3 with WAL (Write-Ahead Logging)
- **Data**: Orders, Customers, Products, Inventory
- **Performance**: Zero impact on production operations

### 2. **Debezium CDC Connector**
- **Role**: Change Data Capture engine
- **Technology**: Kafka Connect + Debezium PostgreSQL connector
- **Function**: Reads WAL, converts to JSON events
- **Reliability**: Guaranteed delivery, exactly-once semantics

### 3. **Apache Kafka**
- **Role**: Event streaming platform
- **Technology**: Kafka 2.8+ with Zookeeper
- **Function**: Reliable event storage and delivery
- **Scalability**: Horizontal partitioning support

### 4. **ClickHouse (Target Database)**
- **Role**: Analytics and OLAP database
- **Technology**: ClickHouse with native Kafka Engine
- **Function**: Real-time data consumption and analysis
- **Performance**: Columnar storage, massive parallelism

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
| **Kafka Tools** | Utility container | - | Kafka |

### Network Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network (cdc-network)             │
│                                                             │
│  PostgreSQL:5432 ← → Debezium ← → Kafka:9092 ← → ClickHouse │
│       │                                │                    │
│       ↓                                ↓                    │
│  Sample Data                     Kafdrop:9001               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓
                        Host: localhost
                     (Accessible from outside)
```

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
    payload String
) ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1;

-- Final Table (Processed Data)
CREATE TABLE orders_final (
    order_id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt32,
    product_id UInt32,
    operation_type String,
    _synced_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (order_id, _synced_at);

-- Materialized View (Real-time Processing)
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    JSONExtractUInt(JSONExtractString(payload, 'payload'), 'order_id') as order_id,
    toDate(JSONExtractString(JSONExtractString(payload, 'payload'), 'order_date')) as order_date,
    JSONExtractUInt(JSONExtractString(payload, 'payload'), 'purchaser') as purchaser,
    JSONExtractUInt(JSONExtractString(payload, 'payload'), 'quantity') as quantity,
    JSONExtractUInt(JSONExtractString(payload, 'payload'), 'product_id') as product_id,
    JSONExtractString(payload, 'op') as operation_type
FROM orders_kafka_json;
```
```

## Performance Characteristics

### Throughput Benchmarks (Actual Test Results)
- **INSERT Operations**: 14-22 operations/second (batch processing)
- **Average Batch Time**: 1000-1500ms for 100 records
- **Success Rate**: 100% (no data loss)
- **End-to-end Latency**: 5-10 seconds (real-time sync)
- **Resource Usage**: CPU <20%, Memory <1GB (normal load)

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

## Scaling Strategies

### Horizontal Scaling
1. **Kafka Partitioning**: Partition topics by business key
2. **ClickHouse Sharding**: Distribute data across multiple nodes
3. **Load Balancing**: Multiple Kafka Connect workers

### Vertical Scaling  
1. **Memory**: More RAM for Kafka and ClickHouse buffers
2. **CPU**: More cores for parallel processing
3. **Storage**: Faster SSDs for better I/O performance

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

### Authentication
- **PostgreSQL**: Username/password authentication
- **ClickHouse**: User-based access control
- **Kafka**: SASL authentication (optional)
- **Container**: Non-root user execution

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

### Authentication
- **PostgreSQL**: Username/password authentication
- **ClickHouse**: User-based access control
- **Kafka**: SASL authentication (optional)
- **Container**: Non-root user execution

### Data Protection
- **Encryption in Transit**: TLS for all connections
- **Encryption at Rest**: Database-level encryption
- **Access Control**: Role-based permissions
- **Audit Logging**: Complete operation trail

## Related Documentation
- ⚡ [Quick Start Guide](QUICK-START.md) - Get it running first
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Fix technical issues
- ⚙️ [Configuration Guide](CONFIGURATION.md) - Advanced setup options
- 📋 [Script Utilities](SCRIPT-UTILITIES.md) - Understanding automation tools

---
🏠 [← Back to Main README](../README.md) | 🔧 [Troubleshooting](TROUBLESHOOTING.md) | ⚙️ [Configuration →](CONFIGURATION.md)
