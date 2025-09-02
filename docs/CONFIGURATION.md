# ⚙️ Configuration Guide

**Perfect for:** Advanced users who want to customize the CDC pipeline

---
🏠 [← Back to Main README](../README.md) | 🏗️ [Architecture Guide](ARCHITECTURE.md) | 🔧 [Troubleshooting →](TROUBLESHOOTING.md)

## Environment Configuration

### Core Environment Variables
```bash
# Database Configuration
POSTGRES_HOST=postgres-source
POSTGRES_PORT=5432
POSTGRES_DB=inventory
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Kafka Configuration
KAFKA_BROKER=kafka:9092
KAFKA_CONNECT_REST_PORT=8083

# ClickHouse Configuration
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_TCP_PORT=9000
```

## Connector Configuration

### Debezium Source Connector
```json
{
  "name": "postgres-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres-source",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "inventory",
    "database.server.name": "postgres-server",
    "table.include.list": "inventory.orders,inventory.customers,inventory.products",
    "plugin.name": "pgoutput",
    "publication.autocreate.mode": "filtered"
  }
}
```

### ClickHouse Kafka Engine Tables
```sql
CREATE TABLE orders_kafka_json (
    payload String
) ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1;
```

## Script Configuration

### Automated Setup
For complete setup, use the provided scripts:
```powershell
# Complete pipeline setup
.\scripts\setup.ps1

# Performance testing
.\scripts\cdc-stress-insert.ps1

# Monitoring and health check
.\scripts\cdc-monitor.ps1
```

### Manual ClickHouse Setup
```powershell
# Execute ClickHouse setup SQL
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery
```

## Performance Tuning

### ClickHouse Optimization
```sql
-- Optimized final table structure
CREATE TABLE orders_final (
    order_id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt32,
    product_id UInt32,
    operation_type String,
    _synced_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (order_id, _synced_at)
SETTINGS 
    index_granularity = 8192;
```

### Stress Test Configuration
Edit script parameters in `.\scripts\cdc-stress-insert.ps1`:
```powershell
# Default configuration
$RecordCount = 1000      # Total records to insert
$BatchSize = 100         # Records per batch
$DelayBetweenBatches = 1 # Seconds between batches
```

### Kafka Optimization
```yaml
# Kafka settings in docker-compose.yml
environment:
  KAFKA_NUM_PARTITIONS: 1
  KAFKA_DEFAULT_REPLICATION_FACTOR: 1
  KAFKA_LOG_RETENTION_MS: 604800000  # 7 days
  KAFKA_LOG_SEGMENT_BYTES: 1073741824  # 1GB
  KAFKA_HEAP_OPTS: "-Xmx512M -Xms512M"
```

### Container Resource Limits
```yaml
# Resource optimization in docker-compose.yml
services:
  kafka-connect:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  
  clickhouse:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

## Security Configuration

### Basic Security
```yaml
# Docker security
security_opt:
  - no-new-privileges:true
read_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=100m
```

### Authentication
```xml
<!-- ClickHouse users.xml -->
<users>
  <cdc_user>
    <password>secure_password</password>
    <networks>
      <ip>172.20.0.0/16</ip>
    </networks>
    <profile>default</profile>
    <quota>default</quota>
  </cdc_user>
</users>
```

## Custom Table Setup

### Adding New Tables to CDC Pipeline
```sql
-- Add new table to CDC pipeline
CREATE TABLE custom_table_kafka (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.custom_table',
    kafka_group_name = 'clickhouse_custom_table_group',
    kafka_format = 'LineAsString';

-- Create target table
CREATE TABLE custom_table_final (
    id Int32,
    name String,
    created_at DateTime,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, _synced_at);

-- Create materialized view
CREATE MATERIALIZED VIEW custom_table_mv TO custom_table_final AS
SELECT 
    JSONExtractInt(raw_message, 'payload', 'after', 'id') as id,
    JSONExtractString(raw_message, 'payload', 'after', 'name') as name,
    parseDateTimeBestEffort(JSONExtractString(raw_message, 'payload', 'after', 'created_at')) as created_at,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM custom_table_kafka;
```

## Related Documentation
- ⚡ [Quick Start Guide](QUICK-START.md) - Get started first
- �️ [Architecture Guide](ARCHITECTURE.md) - Understanding the system
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Fix configuration issues
- 📋 [Script Utilities](SCRIPT-UTILITIES.md) - Automation tools
- 🏛️ [Legacy Documentation](../README-LEGACY.md) - Complete reference

---
�🏠 [← Back to Main README](../README.md) | 🏗️ [Architecture Guide](ARCHITECTURE.md) | 🔧 [Troubleshooting →](TROUBLESHOOTING.md)
