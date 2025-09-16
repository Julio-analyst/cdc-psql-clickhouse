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
    "database.server.name": "postgres-server",
    "table.include.list": "inventory.orders",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_slot",
    "publication.name": "debezium_pub",
    "topic.prefix": "postgres-server"
  
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

## 8. 📈 Setup Grafana Dashboard - Step by Step

### 8.1 Login ke Grafana
1. **Buka browser** dan akses: http://localhost:3000
2. **Login credentials**:
   - Username: `admin`
   - Password: `admin`
3. **Skip change password** (atau ganti jika diperlukan)
4. **Welcome screen** → Click **"Skip"**

### 8.2 Verify Data Sources (Auto-configured)

#### 8.2.1 Check ClickHouse Data Source
1. **Settings** (⚙️) → **Data Sources**
2. **ClickHouse** → Click to open
3. **Connection settings** should show:
   - **URL**: `http://clickhouse:8123`
   - **Database**: `default`
   - **Username**: `default`
   - **Password**: (empty)
4. **Save & Test** → Should show ✅ **"Data source is working"**

#### 8.2.2 Check Prometheus Data Source
1. **Back to Data Sources** → **Prometheus**
2. **URL** should show: `http://prometheus:9090`
3. **Save & Test** → Should show ✅ **"Data source is working"**

**Troubleshooting Data Sources:**
```powershell
# If data sources fail, check container connectivity
docker exec -it grafana ping clickhouse
docker exec -it grafana ping prometheus
```

### 8.3 Import Pre-built Dashboard

#### 8.3.1 Auto-imported Dashboard
1. **Dashboards** (📊) → **Browse**
2. Look for **"CDC Pipeline Monitoring"** dashboard
3. **Click to open**

#### 8.3.2 Manual Import (if auto-import failed)
1. **Dashboards** → **Import**
2. **Upload JSON file** → Browse to `grafana-config/dashboards/`
3. **Select dashboard file** → **Load**
4. **Select data sources**:
   - **ClickHouse**: Choose "ClickHouse"
   - **Prometheus**: Choose "Prometheus"
5. **Import**

### 8.4 Create Dashboard from Scratch (Alternative)

#### 8.4.1 Create New Dashboard
1. **Dashboards** → **New** → **New Dashboard**
2. **Add visualization**

#### 8.4.2 Add CDC Operations Chart (Pie Chart)
1. **Add panel** → **Visualization**: Pie Chart
2. **Data source**: ClickHouse
3. **Query**:
```sql
SELECT 
    operation,
    count(*) as count
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 24 HOUR
GROUP BY operation
```
4. **Panel title**: "CDC Operations (Last 24h)"
5. **Apply**

#### 8.4.3 Add Records Timeline (Time Series)
1. **Add panel** → **Visualization**: Time series
2. **Data source**: ClickHouse
3. **Query**:
```sql
SELECT 
    toStartOfHour(_synced_at) as time,
    count(*) as records
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 7 DAY
GROUP BY time
ORDER BY time
```
4. **Panel title**: "Records Synced Over Time"
5. **X-axis**: time
6. **Y-axis**: records
7. **Apply**

#### 8.4.4 Add Recent Orders Table
1. **Add panel** → **Visualization**: Table
2. **Data source**: ClickHouse
3. **Query**:
```sql
SELECT 
    id,
    order_date,
    purchaser,
    quantity,
    product_id,
    operation,
    _synced_at
FROM orders_final 
ORDER BY _synced_at DESC 
LIMIT 50
```
4. **Panel title**: "Recent Orders"
5. **Apply**

#### 8.4.5 Add Key Metrics (Stat Panels)
**Total Records Panel:**
1. **Add panel** → **Visualization**: Stat
2. **Data source**: ClickHouse
3. **Query**:
```sql
SELECT count(*) as total_records FROM orders_final
```
4. **Panel title**: "Total Records"
5. **Unit**: Short (1000)
6. **Apply**

**Records Today Panel:**
1. **Add panel** → **Visualization**: Stat
2. **Query**:
```sql
SELECT count(*) as today_records 
FROM orders_final 
WHERE _synced_at >= today()
```
3. **Panel title**: "Records Today"
4. **Apply**

### 8.5 Add System Monitoring Panels (Prometheus)

#### 8.5.1 Container Resource Usage
1. **Add panel** → **Visualization**: Time series
2. **Data source**: Prometheus
3. **Query**:
```promql
rate(container_cpu_usage_seconds_total{name=~"clickhouse|kafka|postgres-source"}[5m]) * 100
```
4. **Panel title**: "Container CPU Usage (%)"
5. **Legend**: `{{name}}`
6. **Apply**

#### 8.5.2 Memory Usage
1. **Add panel** → **Visualization**: Time series
2. **Data source**: Prometheus
3. **Query**:
```promql
container_memory_usage_bytes{name=~"clickhouse|kafka|postgres-source"} / 1024 / 1024 / 1024
```
4. **Panel title**: "Container Memory Usage (GB)"
5. **Legend**: `{{name}}`
6. **Unit**: Bytes (GB)
7. **Apply**

### 8.6 Configure Dashboard Settings

#### 8.6.1 Dashboard Properties
1. **Dashboard settings** (⚙️ top right)
2. **General**:
   - **Title**: "CDC Pipeline Monitoring"
   - **Tags**: cdc, pipeline, kafka, clickhouse
   - **Timezone**: Browser
3. **Time options**:
   - **Refresh**: 30s, 1m, 5m, 15m
   - **Time range**: Last 24 hours
4. **Save dashboard**

#### 8.6.2 Panel Organization
1. **Drag panels** to arrange layout
2. **Resize panels** by dragging corners
3. **Group related panels** together:
   - **Top row**: Key metrics (Stat panels)
   - **Middle row**: Time series charts
   - **Bottom row**: Tables and details

### 8.7 Setup Auto-refresh
1. **Time range picker** (top right)
2. **Refresh dropdown** → Select **"30s"**
3. **Apply** → Dashboard will auto-refresh every 30 seconds

### 8.8 Create Alerts (Optional)

#### 8.8.1 Setup Alert for CDC Lag
1. **Edit panel** "Records Synced Over Time"
2. **Alert tab** → **Create Alert**
3. **Condition**:
   - **IS BELOW**: 10 (records per hour)
   - **FOR**: 5m
4. **Notification**: Create notification channel (email/Slack)
5. **Save**

### 8.9 Verify Dashboard Functionality

#### 8.9.1 Test Data Visibility
1. **Check all panels** show data
2. **Time range**: Last 7 days → Should show historical data
3. **Refresh**: Click refresh → Data should update

#### 8.9.2 Test Real-time Updates
1. **Insert test data** in PostgreSQL:
```sql
INSERT INTO inventory.orders (id, order_date, purchaser, quantity, product_id) 
VALUES (88888, CURRENT_DATE, 1002, 3, 103);
```
2. **Wait 30 seconds** → Dashboard should update automatically
3. **Check panels**:
   - Pie chart: New operation count
   - Timeline: New data point
   - Table: New record visible

### 8.10 Troubleshooting Dashboard Issues

#### Issue 1: "No Data" in Panels
**Check data exists in ClickHouse:**
```sql
-- Test in DBeaver (ClickHouse connection)
SELECT count(*) FROM orders_final;
SELECT * FROM orders_final LIMIT 5;
```

**Test queries in Grafana Explore:**
1. **Explore** (compass icon) → **ClickHouse**
2. **Run query manually**:
```sql
SELECT operation, count(*) FROM orders_final GROUP BY operation;
```
3. **Should return results** → If not, data pipeline issue

#### Issue 2: Connection Errors
```powershell
# Check container network
docker network ls
docker exec -it grafana nslookup clickhouse
docker exec -it grafana nslookup prometheus
```

#### Issue 3: Query Errors
- **Check ClickHouse syntax** (not MySQL/PostgreSQL)
- **Use toDateTime()** for timestamp conversions
- **Use GROUP BY** for aggregations
- **Check column names** match actual table schema

#### Issue 4: Performance Issues
1. **Add LIMIT** to large queries
2. **Use time filters**: `WHERE _synced_at >= now() - INTERVAL 1 DAY`
3. **Optimize ClickHouse queries** with proper indexes
4. **Reduce refresh frequency** if needed

### 8.11 Export/Backup Dashboard
1. **Dashboard settings** → **JSON Model**
2. **Copy JSON** to clipboard
3. **Save to file**: `cdc-dashboard-backup.json`
4. **Version control**: Commit to repository

---

**✅ Grafana Setup Complete!** 

Dashboard features:
- 📊 **Real-time CDC monitoring**
- 📈 **Historical trend analysis** 
- 🔍 **Detailed record tracking**
- 🚨 **Alert capabilities** (optional)
- 📱 **Auto-refresh every 30s**

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

- **[DBeaver Setup](DBEAVER-SETUP.md)** - Database connection guide
- **[Architecture Overview](ARCHITECTURE.md)** - Technical deep dive
- **[Configuration Reference](CONFIGURATION.md)** - All service configurations  
- **[Database Connection Troubleshooting](DATABASE-CONNECTION-TROUBLESHOOTING.md)** - Connection issues
- **[Kafka Engine Explained](KAFKA-ENGINE-EXPLAINED.md)** - ClickHouse Kafka Engine guide

---

**🎉 Congratulations!** Your CDC pipeline is now fully operational with real-time data sync and comprehensive monitoring!
