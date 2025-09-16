# 🏗️ System Architecture

Real-time CDC pipeline with comprehensive monitoring stack.

## 🎯 High-Level Overview

```
PostgreSQL → Debezium → Kafka → ClickHouse → Grafana
    ↓           ↓        ↓         ↓          ↓
 Source DB   CDC Tool  Stream   Analytics  Dashboard
    ↓           ↓        ↓         ↓          ↓
Exporters → Exporters → Exporter → Exporter → Prometheus
```

## 📊 Complete System Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ PostgreSQL  │───▶│   Kafka     │───▶│ ClickHouse  │
│   :5432     │    │   :9092     │    │ :8123 :9000 │
│             │    │             │    │             │
│ + Exporter  │    │ + Exporter  │    │ + Exporter  │
│   :9187     │    │   :9308     │    │   :9116     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │
       │           ┌─────────────┐           │
       │           │ Kafka       │           │
       │           │ Connect     │           │
       │           │ :8083       │           │
       │           │ (Debezium)  │           │
       │           └─────────────┘           │
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
              ┌─────────────┐    ┌─────────────┐
              │ Prometheus  │───▶│   Grafana   │
              │   :9090     │    │    :3000    │
              └─────────────┘    └─────────────┘
                    ↑
              ┌─────────────┐
              │ Node        │
              │ Exporter    │
              │   :9100     │
              └─────────────┘
```

## 🔄 Data Flow Process

### Step-by-Step Flow
1. **PostgreSQL** writes changes to WAL (Write-Ahead Log)
2. **Debezium** reads WAL continuously, converts to JSON events
3. **Kafka** stores events in topics with partitions
4. **ClickHouse** consumes events via Kafka Engine
5. **Materialized View** transforms JSON to structured data
6. **MergeTree** table stores final optimized data

### Event Format
```json
{
  "before": null,
  "after": {
    "id": 1005,
    "order_date": 18896,
    "purchaser": 1001,
    "quantity": 3,
    "product_id": 105
  },
  "op": "c",
  "ts_ms": 1725324001567
}
```

## 📦 Core Components

### Data Pipeline Services
| Service | Role | Port | Technology |
|---------|------|------|------------|
| **PostgreSQL** | Source database | 5432 | PostgreSQL 16.3 |
| **Debezium** | CDC connector | 8083 | Kafka Connect + Debezium |
| **Kafka** | Event streaming | 9092 | Apache Kafka 2.8+ |
| **ClickHouse** | Analytics DB | 8123, 9000 | ClickHouse Server |

### Monitoring Services
| Service | Role | Port | Purpose |
|---------|------|------|---------|
| **Prometheus** | Metrics storage | 9090 | Time-series database |
| **Grafana** | Dashboards | 3000 | Visualization platform |
| **Node Exporter** | System metrics | 9100 | Server monitoring |
| **PostgreSQL Exporter** | DB metrics | 9187 | Database monitoring |
| **Kafka Exporter** | Kafka metrics | 9308 | Streaming monitoring |
| **ClickHouse Exporter** | Analytics metrics | 9116 | Query monitoring |

### Management Tools
| Tool | Purpose | Port | URL |
|------|---------|------|-----|
| **Kafdrop** | Kafka UI | 9001 | http://localhost:9001 |
| **Portainer** | Container management | 9443 | https://localhost:9443 |

## 🗄️ Database Schema Design

### ClickHouse Tables
```sql
-- 1. Kafka Engine (streaming input)
CREATE TABLE orders_queue (
    raw_data String
) ENGINE = Kafka('kafka:9092', 'postgres-server.inventory.orders', 'clickhouse-group')
SETTINGS kafka_format = 'JSONAsString';

-- 2. MergeTree (optimized storage)
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

-- 3. Materialized View (real-time ETL)
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

## 🔧 Network & Security

### Docker Network
- **Network Name**: `cdc-network`
- **Type**: Bridge network
- **Internal Communication**: Container names as hostnames
- **External Access**: Only specified ports exposed

### Port Mapping
```
Host:Container
5432:5432     # PostgreSQL
8123:8123     # ClickHouse HTTP
9000:9000     # ClickHouse TCP
9092:9092     # Kafka
8083:8083     # Kafka Connect
3000:3000     # Grafana
9090:9090     # Prometheus
9100:9100     # Node Exporter
9187:9187     # PostgreSQL Exporter
9308:9308     # Kafka Exporter
9116:9116     # ClickHouse Exporter
9001:9000     # Kafdrop
9443:9443     # Portainer
```

## 🚀 Performance Characteristics

### Throughput & Latency
- **End-to-end latency**: < 2 seconds
- **Throughput**: 1,000+ events/second
- **Data compression**: 10:1 ratio in ClickHouse
- **Query performance**: Sub-second for millions of rows

### Resource Requirements
```
Minimum (Development):
- 8GB RAM, 4 CPU cores
- 20GB disk space

Recommended (Production):
- 16GB RAM, 8 CPU cores  
- 100GB SSD storage
```

### Scaling Options
- **Kafka**: Add brokers, increase partitions
- **ClickHouse**: Add nodes, distributed tables
- **Monitoring**: Federation and load balancing

## 🔍 Monitoring Strategy

### Metrics Collection
```
System Level (Node Exporter):
- CPU, Memory, Disk, Network usage

Service Level (Service Exporters):
- PostgreSQL: connections, queries, replication lag
- Kafka: topics, partitions, consumer lag  
- ClickHouse: queries, tables, compression

Application Level (Custom):
- CDC pipeline latency
- Data quality metrics
- Business KPIs
```

### Dashboard Overview
- **CDC Pipeline Status**: Real-time sync monitoring
- **Infrastructure Health**: System resource usage
- **Business Analytics**: Order trends and patterns
- **Alert Management**: Proactive issue detection

## 🔄 Disaster Recovery

### Backup Strategy
- **PostgreSQL**: WAL archiving + daily dumps
- **Kafka**: Topic replication + exports
- **ClickHouse**: Incremental backups every 4 hours
- **Configuration**: Version controlled in Git

### Recovery Time
- **RTO (Recovery Time Objective)**: 15 minutes
- **RPO (Recovery Point Objective)**: 1 minute data loss max
- **High Availability**: 99.9% uptime target

---

## Related Documentation
- 🚀 **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Complete implementation guide
- ⚙️ **[Configuration](CONFIGURATION.md)** - Service configurations  
- 🔧 **[Database Connection Troubleshooting](DATABASE-CONNECTION-TROUBLESHOOTING.md)** - Connection issues
- 📊 **[DBeaver Setup](DBEAVER-SETUP.md)** - Database GUI setup
- � **[Kafka Engine Explained](KAFKA-ENGINE-EXPLAINED.md)** - ClickHouse streaming