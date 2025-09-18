# 🚀 Step-by-Step Setup & Konfigurasi CDC Pipeline

## 📋 Overview
Pipeline CDC (Change Data Capture) PostgreSQL → Kafka → ClickHouse dengan monitoring stack lengkap.

**Waktu Setup**: ~10-15 menit  
**Hasil**: Real-time data sync + monitoring dashboard

---

## 1. ✅ Prasyarat

### Sistem Requirements
- **OS**: Windows 10+ / macOS / Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 10GB free space
- **Docker Desktop**: Latest version

### Software Tools
- **Docker Desktop**: [Download here](https://docker.com/products/docker-desktop)
- **DBeaver**: [Download here](https://dbeaver.io/download/) (untuk SQL GUI)
- **Git**: [Download here](https://git-scm.com/) (untuk clone repo)

### Port Requirements
Pastikan port berikut tidak digunakan:
- `3000` (Grafana), `5432` (PostgreSQL), `8123/9000` (ClickHouse)
- `9090` (Prometheus), `9092` (Kafka), `8083` (Kafka Connect)
- `9001` (Kafdrop), `9443` (Portainer)

---

## 2. 📥 Clone & Setup Repository

```powershell
# Clone repository
git clone https://github.com/Julio-analyst/cdc-psql-clickhouse.git
cd cdc-psql-clickhouse

# Verify struktur folder
ls -la
```

**Expected Output:**
```
docker-compose.yml
config/
docs/
grafana-config/
plugins/
scripts/
```

---

## 3. 🐳 Jalankan Infrastructure

```powershell
# Start semua container
docker-compose up -d

# Verify container status (tunggu 2-3 menit)
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Expected Results (19 containers):**
- ✅ Core: postgres-source, clickhouse, kafka, zookeeper
- ✅ CDC: kafka-connect, debezium connectors
- ✅ Monitoring: grafana, prometheus, exporters
- ✅ UI: kafdrop, portainer, kafka-manager

**Troubleshooting Container Issues:**
```powershell
# Jika ada container yang gagal
docker logs <container_name>

# Restart specific container
docker restart <container_name>

# Restart all
docker-compose restart
```

---

## 4. 🔗 Setup Debezium CDC Connector

### 4.1 Access Kafka Connect UI
- URL: http://localhost:8001
- Click **"New Connector"** → **"PostgreSQL Source Connector"**

### 4.2 Connector Configuration
Paste JSON config berikut:

```json
{
  "name": "inventory-connector",
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "database.hostname": "postgres-source",
  "database.port": "5432",
  "database.user": "postgres",
  "database.password": "postgres",
  "database.dbname": "inventory",
  "database.server.name": "dbserver1",
  "plugin.name": "pgoutput",
  "slot.name": "debezium_slot",
  "publication.name": "debezium_pub",
  "table.include.list": "inventory.orders,inventory.customers,inventory.products",
  "topic.prefix": "dbserver1",
  "schema.history.internal.kafka.topic": "dbhistory.inventory",
  "schema.history.internal.kafka.bootstrap.servers": "kafka:9092"
}
```

### 4.3 Verify Connector Status
```powershell
# Check connector status
curl http://localhost:8083/connectors/inventory-connector/status
```

**Expected Response:**
```json
{
  "name": "inventory-connector",
  "connector": {"state": "RUNNING"},
  "tasks": [{"state": "RUNNING"}]
}
```

---

## 5. 🏗️ Setup ClickHouse Tables & Views

### 5.1 Connect DBeaver ke ClickHouse
1. **New Connection** → **ClickHouse**
2. **Host**: `localhost`, **Port**: `8123`
3. **Database**: `default`, **User**: `default`, **Password**: (kosong)
4. **Test Connection** → **OK**

### 5.2 Execute ClickHouse Setup Script

Copy-paste script berikut ke DBeaver (ClickHouse connection):

```sql
-- ===========================
-- ORDERS TABLE SETUP
-- ===========================

-- 1. Kafka Engine table for raw JSON messages
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

-- 2. Final MergeTree table
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

-- 3. Materialized view for real-time processing
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

-- ===========================
-- CUSTOMERS & PRODUCTS SETUP
-- ===========================

-- Similar setup for customers and products...
-- (Add customers_kafka_json, customers_final, customers_mv)
-- (Add products_kafka_json, products_final, products_mv)

-- ===========================
-- MONITORING VIEW
-- ===========================

CREATE VIEW IF NOT EXISTS cdc_operations_summary AS
SELECT 
    'orders' as table_name,
    operation,
    count(*) as count,
    max(_synced_at) as last_sync
FROM orders_final
GROUP BY operation;
```

### 5.3 Verify Tables Created
```sql
-- Check tables
SHOW TABLES FROM default;

-- Check data
SELECT count(*) FROM orders_final;
SELECT * FROM orders_final LIMIT 5;
```

---

## 6. 📊 Test Data Real-time Sync

### 6.1 Insert Test Data (PostgreSQL)
Connect DBeaver ke PostgreSQL:
- **Host**: `localhost`, **Port**: `5432`
- **Database**: `inventory`, **User**: `postgres`, **Password**: `postgres`

```sql
-- Insert test record
INSERT INTO inventory.orders (id, order_date, purchaser, quantity, product_id) 
VALUES (99999, CURRENT_DATE, 1001, 5, 102);

-- Update test
UPDATE inventory.orders SET quantity = 10 WHERE id = 99999;

-- Delete test
DELETE FROM inventory.orders WHERE id = 99999;
```

### 6.2 Verify Sync (ClickHouse)
```sql
-- Check latest synced records
SELECT * FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 5 MINUTE
ORDER BY _synced_at DESC 
LIMIT 10;

-- Check operations summary
SELECT * FROM cdc_operations_summary;
```

**Expected Results:**
- INSERT → operation = 'c' (create)
- UPDATE → operation = 'u' (update)  
- DELETE → operation = 'd' (delete)

---

## 7. 🖥️ Access Web Interfaces

### Core Monitoring UIs

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Grafana** | http://localhost:3000 | admin/admin | Analytics Dashboard |
| **Prometheus** | http://localhost:9090 | - | Metrics Collection |
| **Kafdrop** | http://localhost:9001 | - | Kafka Topics Monitor |
| **ClickHouse** | http://localhost:8123 | - | Query Interface |
| **Portainer** | https://localhost:9443 | admin/admin | Docker Management |

### Kafka Management

| Service | URL | Purpose |
|---------|-----|---------|
| **Kafka Connect UI** | http://localhost:8001 | Connector Management |
| **Kafka Manager** | http://localhost:9002 | Cluster Monitoring |
| **Kafka REST** | http://localhost:8082 | HTTP API |

---

## 8. 📈 Setup Grafana Dashboard

### 8.1 Login & Import Dashboard
1. **Access**: http://localhost:3000 (admin/admin)
2. **Import**: Dashboard "CDC Pipeline Monitoring" (auto-loaded)
3. **Verify**: Data sources ClickHouse & Prometheus

### 8.2 Dashboard Features
- **CDC Operations Distribution**: Pie chart (INSERT/UPDATE/DELETE)
- **Records Synced Timeline**: Time series chart  
- **Recent Orders**: Table with latest 100 records
- **Key Metrics**: Total orders, quantities, sync status

### 8.3 Troubleshooting "No Data"
```sql
-- Test query in Grafana → Explore → ClickHouse
SELECT operation, count(*) as count 
FROM orders_final 
GROUP BY operation;

-- If empty, check data exists
SELECT count(*) FROM orders_final;
```

**Common Issues:**
- **Time range**: Set to "Last 7 days"
- **Data source**: Verify ClickHouse connection
- **Query syntax**: Use ClickHouse SQL format

---

## 9. 🔧 Monitoring & Health Checks

### 9.1 Container Health
```powershell
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check specific service logs
docker logs grafana
docker logs kafka-connect
docker logs clickhouse
```

### 9.2 Connector Status
```powershell
# List all connectors
curl http://localhost:8083/connectors

# Check specific connector
curl http://localhost:8083/connectors/inventory-connector/status

# Check connector config
curl http://localhost:8083/connectors/inventory-connector/config
```

### 9.3 Kafka Topics
Access Kafdrop (http://localhost:9001) untuk melihat:
- **Topics**: dbserver1.inventory.orders, .customers, .products  
- **Messages**: Real-time CDC events
- **Consumer Groups**: clickhouse_orders_group

### 9.4 Prometheus Targets
Access Prometheus (http://localhost:9090/targets) untuk verify:
- ✅ **Node Exporter** (9100): System metrics
- ✅ **Postgres Exporter** (9187): DB metrics  
- ✅ **Kafka Exporter** (9308): Kafka metrics
- ✅ **ClickHouse Exporter** (9116): ClickHouse metrics

---

## 10. 🚨 Common Troubleshooting

### Issue 1: Container Won't Start
```powershell
# Check Docker Desktop running
docker version

# Check port conflicts
netstat -ano | findstr :5432

# Restart Docker Desktop
# Or change ports in docker-compose.yml
```

### Issue 2: Connector Failed
```powershell
# Check connector logs
curl http://localhost:8083/connectors/inventory-connector/status

# Restart connector
curl -X POST http://localhost:8083/connectors/inventory-connector/restart

# Delete and recreate
curl -X DELETE http://localhost:8083/connectors/inventory-connector
# Then recreate via UI
```

### Issue 3: No Data in ClickHouse
```sql
-- Check Kafka consumption
SELECT count(*) FROM orders_kafka_json;

-- Check materialized view
SELECT count(*) FROM orders_mv;

-- Manual materialized view refresh
OPTIMIZE TABLE orders_final;
```

### Issue 4: Grafana No Data
1. **Data Source Test**: Settings → Data Sources → ClickHouse → Save & Test
2. **Query Test**: Explore → ClickHouse → Run query manually
3. **Dashboard Refresh**: Click refresh button or set auto-refresh
4. **Time Range**: Change to longer period (7 days)

---

## 11. 📝 Verification Checklist

### ✅ Infrastructure
- [ ] 19 containers running
- [ ] All ports accessible
- [ ] No container errors in logs

### ✅ CDC Pipeline
- [ ] Debezium connector RUNNING
- [ ] Kafka topics created and receiving messages
- [ ] ClickHouse tables populated with data
- [ ] Real-time sync working (test INSERT/UPDATE/DELETE)

### ✅ Monitoring
- [ ] Grafana dashboard showing data
- [ ] Prometheus targets all UP
- [ ] All web UIs accessible
- [ ] No connection errors

---

## 12. 🎯 Next Steps

### Advanced Configuration
- **Add more tables**: Update `table.include.list` in connector
- **Custom dashboards**: Create new Grafana panels
- **Alerting**: Setup Grafana alerts for sync failures
- **Performance tuning**: Optimize ClickHouse settings

### Production Considerations
- **Security**: Change default passwords
- **Backup**: Setup data backups
- **Scaling**: Add more Kafka partitions
- **Monitoring**: Add custom metrics

---

## 📚 Additional Resources

- **[Grafana Setup Guide](GRAFANA-SETUP.md)** - Detailed dashboard configuration
- **[DBeaver Setup](DBEAVER-SETUP.md)** - Database connection guide
- **[Architecture Overview](ARCHITECTURE.md)** - Technical deep dive
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues & solutions

---

**🎉 Congratulations!** Your CDC pipeline is now fully operational with real-time data sync and comprehensive monitoring!
