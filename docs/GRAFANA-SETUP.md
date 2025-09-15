# 📊 Grafana Setup & Dashboard Configuration Guide

## 🚀 Quick Access
- **URL**: http://localhost:3000
- **Default Login**: `admin` / `admin`
- **Dashboard**: "CDC Pipeline Monitoring" (auto-imported)

---

## 📈 Dashboard Overview

### Real-time CDC Monitoring Dashboard
Pre-configured dashboard dengan 7 panels utama:

#### 1. **CDC Operations Distribution** (Pie Chart)
- **Purpose**: Visualisasi proporsi operasi CDC (INSERT, UPDATE, DELETE)
- **Query**: `SELECT operation, count(*) as count FROM orders_final GROUP BY operation`
- **Use Case**: Monitor balance operasi database

#### 2. **Records Synced Over Time** (Time Series)
- **Purpose**: Trend sync data per jam dalam 24 jam terakhir
- **Query**: `SELECT toDateTime(toStartOfHour(_synced_at)) as time, count(*) as records FROM orders_final WHERE _synced_at >= now() - INTERVAL 24 HOUR GROUP BY time ORDER BY time`
- **Use Case**: Detect sync patterns dan peak hours

#### 3. **Recent Orders** (Table)
- **Purpose**: 100 record terbaru yang masuk ke ClickHouse
- **Query**: `SELECT id, order_date, purchaser, quantity, product_id, operation, _synced_at FROM orders_final ORDER BY _synced_at DESC LIMIT 100`
- **Use Case**: Real-time monitoring data changes

#### 4. **Key Metrics** (4 Stat Panels)
- **Total Orders**: `SELECT count(*) FROM orders_final`
- **Total Quantity**: `SELECT sum(quantity) FROM orders_final`
- **Last Sync Time**: `SELECT max(_synced_at) FROM orders_final`
- **CDC Operations Types**: `SELECT count(DISTINCT operation) FROM orders_final`

### Auto-refresh Settings
- **Interval**: 5 seconds (configurable)
- **Time Range**: Last 24 hours (adjustable)

---

## 🔧 Data Sources Configuration

### 1. ClickHouse Data Source (Primary)
```yaml
Name: ClickHouse
Type: grafana-clickhouse-datasource
URL: http://clickhouse:8123
Database: default
Username: default
Protocol: HTTP
```

**Connection Test:**
- Settings → Data Sources → ClickHouse
- Click **"Save & test"**
- Should show green ✅ "Data source is working"

### 2. Prometheus Data Source (Infrastructure Metrics)
```yaml
Name: Prometheus  
Type: prometheus
URL: http://prometheus:9090
```

**Available Metrics:**
- Node system metrics (CPU, Memory, Disk)
- PostgreSQL database metrics
- Kafka cluster metrics
- ClickHouse performance metrics

### 3. PostgreSQL Data Source (Source Database)
```yaml
Name: PostgreSQL
URL: postgres-source:5432
Database: inventory
Username: postgres
Password: postgres
SSL Mode: disable
```

---

## 🛠️ Manual Data Source Setup

### Add ClickHouse Data Source (if not auto-configured)

1. **Navigate**: Settings → Data Sources → Add data source
2. **Select**: ClickHouse (install plugin if needed)
3. **Configure**:
   ```
   HTTP URL: http://clickhouse:8123
   Server Address: clickhouse
   Server Port: 8123
   Username: default
   Password: (leave empty)
   Default Database: default
   ```
4. **Save & Test**: Should show success message

### Troubleshooting Connection Issues

#### Issue: "Connection refused"
```bash
# Check ClickHouse container
docker logs clickhouse

# Test direct connection
curl http://localhost:8123/?query=SELECT%201
```

#### Issue: "Handshake failed" 
- Verify protocol is set to **HTTP** (not TCP)
- Ensure port 8123 (not 9000)
- Check server address is `clickhouse` (not `localhost`)

#### Issue: "Authentication failed"
- Username: `default`
- Password: leave empty
- Database: `default`

---

## 📊 Custom Queries & Panels

### Essential CDC Monitoring Queries

#### Operations by Time
```sql
SELECT 
    toDateTime(toStartOfHour(_synced_at)) as time,
    operation,
    count(*) as count
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 24 HOUR
GROUP BY time, operation
ORDER BY time;
```

#### Sync Latency Analysis
```sql
SELECT 
    avg(dateDiff('second', order_date, _synced_at)) as avg_latency_seconds,
    max(dateDiff('second', order_date, _synced_at)) as max_latency_seconds
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 1 HOUR;
```

#### Top Customers by Order Volume
```sql
SELECT 
    purchaser,
    count(*) as order_count,
    sum(quantity) as total_quantity
FROM orders_final 
GROUP BY purchaser 
ORDER BY order_count DESC 
LIMIT 10;
```

#### Data Quality Monitoring
```sql
SELECT 
    operation,
    count(*) as count,
    count(*) * 100.0 / sum(count(*)) OVER() as percentage
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 24 HOUR
GROUP BY operation;
```

---

## 🎨 Creating Custom Dashboards

### Step 1: Create New Dashboard
1. **Click**: "+" → Dashboard
2. **Add Panel**: Choose visualization type
3. **Configure Query**: Select ClickHouse data source

### Step 2: Panel Configuration

#### Time Series Panel Example
```json
{
  "title": "Hourly Sync Rate",
  "type": "timeseries",
  "datasource": "ClickHouse",
  "query": "SELECT toDateTime(toStartOfHour(_synced_at)) as time, count(*) as records FROM orders_final WHERE $__timeFilter(_synced_at) GROUP BY time ORDER BY time"
}
```

#### Stat Panel Example  
```json
{
  "title": "Sync Lag (seconds)",
  "type": "stat",
  "datasource": "ClickHouse", 
  "query": "SELECT avg(now() - _synced_at) as lag FROM orders_final WHERE _synced_at >= now() - INTERVAL 5 MINUTE"
}
```

### Step 3: Dashboard Variables

#### Add Time Range Variable
1. **Settings** → Variables → Add variable
2. **Name**: `time_range`
3. **Type**: `Interval`
4. **Values**: `5m,15m,1h,6h,12h,1d,7d`

#### Add Table Filter Variable
```sql
-- Variable Query (Multi-value)
SELECT DISTINCT 'orders' as table_name
UNION ALL
SELECT DISTINCT 'customers' as table_name  
UNION ALL
SELECT DISTINCT 'products' as table_name;
```

---

## 🚨 Alerting & Notifications

### Alert Rules Setup

#### High Sync Latency Alert
```sql
-- Condition: If sync lag > 60 seconds
SELECT avg(now() - _synced_at) as lag_seconds
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 5 MINUTE
HAVING lag_seconds > 60;
```

#### No New Data Alert
```sql
-- Condition: If no records in last 10 minutes
SELECT count(*) as recent_count
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 10 MINUTE
HAVING recent_count = 0;
```

#### CDC Operation Failures
```sql
-- Monitor for sync interruptions
SELECT count(*) as sync_count
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 1 HOUR
HAVING sync_count < 10; -- Adjust threshold
```

### Notification Channels

#### Email Notifications
1. **Alerting** → Notification channels → New channel
2. **Type**: Email
3. **Addresses**: admin@yourcompany.com
4. **Subject**: `CDC Pipeline Alert - {{.RuleName}}`

#### Slack Integration
```json
{
  "webhook_url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
  "channel": "#data-alerts",
  "title": "CDC Pipeline Alert",
  "text": "Alert: {{.Message}}"
}
```

---

## 🔍 Advanced Dashboard Features

### Dashboard Links
Add navigation links to related dashboards:
```json
{
  "title": "Related Dashboards",
  "links": [
    {"title": "Kafka Monitoring", "url": "/d/kafka-dashboard"},
    {"title": "PostgreSQL Metrics", "url": "/d/postgres-dashboard"},
    {"title": "System Overview", "url": "/d/node-dashboard"}
  ]
}
```

### Templating with Variables
Use variables in queries for dynamic dashboards:
```sql
-- Use $table_name variable
SELECT operation, count(*) 
FROM ${table_name}_final 
WHERE _synced_at >= $__timeFrom
GROUP BY operation;
```

### Panel Drilldown
Configure panels to link to detailed views:
- **Data Links**: Link pie chart slices to filtered tables
- **URL Parameters**: Pass time ranges and filters
- **Dashboard Links**: Navigate to related monitoring

---

## 🎯 Performance Optimization

### Query Optimization Tips

#### Use Time Filters
```sql
-- Good: Use time-based filtering
SELECT * FROM orders_final 
WHERE _synced_at >= $__timeFrom 
AND _synced_at <= $__timeTo;

-- Avoid: Full table scans
SELECT * FROM orders_final;
```

#### Leverage ClickHouse Features
```sql
-- Use PREWHERE for better performance
SELECT id, operation, _synced_at 
FROM orders_final 
PREWHERE _synced_at >= now() - INTERVAL 1 HOUR
WHERE operation = 'c';

-- Use sampling for large datasets
SELECT operation, count(*) 
FROM orders_final SAMPLE 0.1 
GROUP BY operation;
```

#### Dashboard Performance Settings
- **Query timeout**: 30 seconds
- **Max data points**: 1000
- **Refresh intervals**: Balance freshness vs performance
- **Panel caching**: Enable for static panels

---

## 📋 Troubleshooting Guide

### Common Issues & Solutions

#### 1. "No Data" in Panels

**Diagnosis:**
```sql
-- Test basic connectivity
SELECT 1;

-- Check if data exists
SELECT count(*) FROM orders_final;

-- Verify time range
SELECT min(_synced_at), max(_synced_at) FROM orders_final;
```

**Solutions:**
- ✅ Verify ClickHouse data source connection
- ✅ Check dashboard time range (expand to 7 days)
- ✅ Confirm CDC pipeline is running and syncing
- ✅ Test query directly in Explore tab

#### 2. Query Timeout Errors

**Solutions:**
```sql
-- Add LIMIT to large queries
SELECT * FROM orders_final 
ORDER BY _synced_at DESC 
LIMIT 1000;

-- Use time-based partitioning
SELECT * FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 1 HOUR;
```

#### 3. Dashboard Won't Load

**Diagnosis:**
```bash
# Check Grafana logs
docker logs grafana

# Test ClickHouse connectivity
curl http://localhost:8123/?query=SELECT%201
```

**Solutions:**
- Restart Grafana container
- Verify data source configuration
- Check network connectivity between containers

#### 4. Incorrect Data/Metrics

**Diagnosis:**
```sql
-- Verify data integrity
SELECT 
    operation,
    count(*) as count,
    min(_synced_at) as first_sync,
    max(_synced_at) as last_sync
FROM orders_final 
GROUP BY operation;
```

**Solutions:**
- Check CDC connector status
- Verify materialized views are working
- Confirm time zones are consistent

---

## 📤 Export/Import Dashboards

### Export Dashboard
1. **Dashboard Settings** → JSON Model
2. **Copy** JSON content
3. **Save** to file (e.g., `cdc-dashboard.json`)

### Import Dashboard
1. **Home** → Import
2. **Upload JSON file** or paste JSON
3. **Select** data sources
4. **Import**

### Version Control
```bash
# Save dashboard configs to git
git add grafana-config/dashboards/
git commit -m "Update CDC monitoring dashboard"
```

---

## 🔗 Integration dengan Tools Lain

### Prometheus Integration
Create panels using Prometheus metrics:
```promql
# System CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Kafka lag
kafka_consumer_lag_sum{group="clickhouse_orders_group"}

# PostgreSQL connections
pg_stat_database_numbackends{datname="inventory"}
```

### External APIs
```json
// Panel configuration for external data
{
  "datasource": "JSON API",
  "url": "http://localhost:8083/connectors/inventory-connector/status",
  "method": "GET"
}
```

---

## 📚 Best Practices

### Dashboard Design
- **Consistent color scheme**: Use standard colors for operations (green=INSERT, blue=UPDATE, red=DELETE)
- **Logical grouping**: Group related panels together
- **Clear titles**: Descriptive panel titles and descriptions
- **Appropriate time ranges**: Set sensible defaults

### Query Efficiency  
- **Filter early**: Use PREWHERE clause in ClickHouse
- **Aggregate smartly**: Pre-aggregate data when possible
- **Cache results**: Enable query result caching
- **Limit data points**: Use appropriate LIMIT clauses

### Alerting Strategy
- **Meaningful thresholds**: Set realistic alert thresholds
- **Avoid alert fatigue**: Don't over-alert on minor issues
- **Clear descriptions**: Write helpful alert messages
- **Proper escalation**: Set up proper notification chains

### Maintenance
- **Regular cleanup**: Remove unused dashboards and panels
- **Performance review**: Monitor dashboard load times
- **Data retention**: Configure appropriate data retention policies
- **Documentation**: Keep dashboard documentation updated

---

## 🎓 Advanced Features

### Custom Plugins
Install additional Grafana plugins:
```bash
# Install via CLI
grafana-cli plugins install grafana-worldmap-panel

# Or via Docker environment
GF_INSTALL_PLUGINS=grafana-worldmap-panel,grafana-clock-panel
```

### API Integration
Use Grafana API for automation:
```bash
# Create dashboard via API
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboard.json

# Get dashboard
curl http://admin:admin@localhost:3000/api/dashboards/uid/cdc-pipeline
```

### Advanced Templating
Complex variable queries:
```sql
-- Cascading variables
SELECT DISTINCT database 
FROM system.tables 
WHERE name LIKE '%_final';

-- Multi-query variables  
SELECT name FROM 
(
  SELECT 'orders' as name
  UNION ALL
  SELECT 'customers' as name
) 
WHERE name LIKE '%${search}%';
```

---

## 📈 Monitoring Metrics Reference

### CDC Pipeline Health Metrics
- **Sync Latency**: Time between source change and ClickHouse update
- **Throughput**: Records processed per second
- **Error Rate**: Failed CDC operations percentage
- **Data Quality**: Completeness and consistency metrics

### Infrastructure Metrics  
- **CPU Usage**: System and container CPU utilization
- **Memory Usage**: RAM consumption by services
- **Disk I/O**: Read/write operations and latency
- **Network Traffic**: Data transfer rates

### Business Metrics
- **Order Volume**: Total orders processed
- **Revenue Impact**: Financial metrics from CDC data
- **Customer Activity**: User behavior patterns
- **Product Performance**: Top-selling items and trends

---

**🎉 Success!** Your Grafana monitoring is now fully configured with comprehensive CDC pipeline visibility and alerting!