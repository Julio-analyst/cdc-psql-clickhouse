# 🏗️ Complete System Architecture

**Perfect for:** Developers, DevOps engineers, System architects, and technical decision makers

## 📊 Enterprise-Grade CDC Pipeline with Full-Stack Monitoring

### High-Level Architecture (Updated with Monitoring Stack)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │    Apache        │    │   ClickHouse    │
│   (Source DB)   │───▶│    Kafka         │───▶│  (Analytics)    │
│                 │    │   + Debezium     │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Postgres        │    │ Kafka           │    │ ClickHouse      │
│ Exporter        │    │ Exporter        │    │ Exporter        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌──────────────────┐
                    │   Prometheus     │◄────── Node Exporter
                    │   (Metrics)      │
                    └──────────────────┘
                                 │
                                 ▼
                    ┌──────────────────┐
                    │    Grafana       │
                    │  (Dashboards)    │
                    └──────────────────┘
```

### Complete Data & Monitoring Flow
```
PostgreSQL WAL → Debezium → Kafka Topics → ClickHouse Kafka Engine → MergeTree Tables
      ↓            ↓           ↓               ↓                        ↓
   Postgres      Kafka      Topic           Real-time               Analytics
   Exporter     Exporter   Monitoring      Consumption             Queries
      ↓            ↓           ↓               ↓                        ↓
      └────────────┴───────────┴───────► Prometheus ◄─────────────────┘
                                              ↓
                                         Grafana Dashboards
                                      (Real-time CDC Monitoring)
```

## 🎯 Core CDC Pipeline Components

### 1. **PostgreSQL (Source Database)**
- **Role**: Primary OLTP database with business-critical data
- **Technology**: PostgreSQL 16.3 with WAL (Write-Ahead Logging)
- **Port**: 5432
- **Data Models**: Orders, Customers, Products, Inventory
- **Performance**: Zero impact on production operations (async WAL reading)
- **Configuration**: Logical replication enabled, pgoutput plugin
- **Monitoring**: Connection count, query performance, replication lag

### 2. **Debezium CDC Connector**
- **Role**: Change Data Capture engine with exactly-once semantics  
- **Technology**: Kafka Connect + Debezium PostgreSQL connector v2.6.0
- **Port**: 8083 (Kafka Connect REST API)
- **Function**: 
  - Reads PostgreSQL WAL in real-time
  - Converts binary changes to structured JSON events
  - Handles schema changes automatically
- **Reliability**: 
  - Guaranteed delivery with offset tracking
  - Handles connector restarts gracefully
  - Maintains chronological event order
- **Configuration**: Publication-based CDC, custom slot management

### 3. **Apache Kafka (Event Streaming)**
- **Role**: Distributed event streaming platform
- **Technology**: Apache Kafka 2.8+ with KRaft (no Zookeeper dependency)
- **Ports**: 9092 (client), 9101 (JMX metrics)
- **Function**:
  - Reliable, partitioned event storage
  - Horizontal scaling support
  - Event replay capabilities
- **Topics**: 
  - `postgres-server.inventory.orders` (main data events)
  - `postgres-server.heartbeat` (connector health)
  - `postgres-server.schema-changes` (DDL changes)
- **Monitoring**: Message throughput, consumer lag, partition health

### 4. **ClickHouse (Analytics Database)**
- **Role**: High-performance OLAP database with native Kafka integration
- **Technology**: ClickHouse Server with Kafka Engine
- **Ports**: 8123 (HTTP), 9000 (native TCP)
- **Function**:
  - Real-time data consumption from Kafka
  - Columnar storage with aggressive compression
  - Massive parallel query processing
- **Tables**:
  - `orders_queue` (Kafka Engine - streaming ingestion)
  - `orders_final` (MergeTree Engine - optimized analytics)
  - `orders_mv` (Materialized View - automatic ETL)
- **Performance**: Sub-second query response for billions of rows

## 📈 Complete Monitoring & Observability Stack

### 5. **Prometheus (Metrics Collection)**
- **Role**: Time-series metrics collection and storage
- **Technology**: Prometheus Server v2.40+
- **Port**: 9090 (web UI and API)
- **Function**:
  - Scrapes metrics from all exporters every 15 seconds
  - Stores time-series data with configurable retention
  - Provides PromQL query language for metrics
- **Targets**: All exporters, self-monitoring
- **Retention**: 30 days (configurable)

### 6. **Grafana (Visualization & Dashboards)**
- **Role**: Analytics dashboards and alerting platform
- **Technology**: Grafana Enterprise v9.0+
- **Port**: 3000 (web interface)
- **Function**:
  - Real-time CDC pipeline monitoring
  - Business metrics visualization  
  - Alert management and notifications
- **Dashboards**: 
  - CDC Pipeline Monitoring (pre-configured)
  - Infrastructure Metrics
  - Business Analytics
- **Data Sources**: ClickHouse, Prometheus, PostgreSQL

### 7. **Node Exporter (System Metrics)**
- **Role**: Host-level metrics collection
- **Technology**: Prometheus Node Exporter
- **Port**: 9100 (metrics endpoint)
- **Metrics**:
  - CPU, Memory, Disk usage
  - Network I/O statistics
  - System load and processes
  - File system information

### 8. **PostgreSQL Exporter (Database Metrics)**
- **Role**: PostgreSQL-specific metrics collection
- **Technology**: postgres_exporter
- **Port**: 9187 (metrics endpoint)
- **Metrics**:
  - Connection counts and states
  - Query performance statistics
  - Replication lag monitoring
  - Table and index statistics
  - WAL generation rates

### 9. **Kafka Exporter (Streaming Metrics)**
- **Role**: Kafka cluster and topic metrics
- **Technology**: kafka_exporter
- **Port**: 9308 (metrics endpoint)
- **Metrics**:
  - Topic partition counts and sizes
  - Consumer group lag monitoring
  - Broker health and performance
  - Message production/consumption rates

### 10. **ClickHouse Exporter (Analytics DB Metrics)**
- **Role**: ClickHouse performance and health metrics
- **Technology**: clickhouse_exporter
- **Port**: 9116 (metrics endpoint)  
- **Metrics**:
  - Query execution times and counts
  - Table sizes and compression ratios
  - Kafka Engine consumption rates
  - Memory and CPU usage per query

## 🔄 Comprehensive Data Flow Architecture

### End-to-End Process with Monitoring
```
PostgreSQL → Debezium → Kafka → ClickHouse → Grafana → Alerts
     ↓          ↓        ↓        ↓           ↓         ↓
   WAL        JSON     Topics   MergeTree  Dashboard  Actions
  Changes    Events  Streaming   Tables    Queries   Notifications
     ↓          ↓        ↓        ↓           ↓         ↓
  PG-Exp    Kafka-Exp  Topic    CH-Exp    Prometheus Alert-Mgr
 Metrics     Metrics   Monitor  Metrics    Collection Rules
```

### Step-by-Step Data Processing
1. **Change Detection**: PostgreSQL writes DML operations to WAL (binary log)
2. **Event Capture**: Debezium connector reads WAL in real-time, converts to JSON events  
3. **Event Publishing**: Structured events sent to partitioned Kafka topics
4. **Event Consumption**: ClickHouse Kafka Engine consumes events continuously
5. **Data Transformation**: Materialized views parse JSON to columnar format
6. **Storage Optimization**: Final data stored in MergeTree with compression
7. **Metrics Collection**: All services expose metrics to Prometheus
8. **Dashboard Visualization**: Grafana displays real-time pipeline health
9. **Alert Processing**: Automated notifications for issues and anomalies