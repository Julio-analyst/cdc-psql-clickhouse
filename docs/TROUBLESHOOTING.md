# 🔧 Comprehensive Troubleshooting Guide

**Perfect for:** When things go wrong and you need immediate, expert-level solutions

---
**🏠 [← Back to Main README](../README.md)** | **🏗️ [Architecture Guide](ARCHITECTURE.md)** | **⚙️ [Configuration →](CONFIGURATION.md)**

---

## 🚨 Emergency Quick Start

### 30-Second Health Check
```powershell
# Complete system status in one command
Write-Host "=== SYSTEM HEALTH CHECK ===" -ForegroundColor Cyan

# 1. Container Status
Write-Host "`n1. CONTAINER STATUS:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | findstr -v "NAMES"

# 2. Service Connectivity  
Write-Host "`n2. SERVICE CONNECTIVITY:" -ForegroundColor Yellow
$services = @(
    @{Name="PostgreSQL"; URL="http://localhost:5432"; Test="nc -z localhost 5432"},
    @{Name="Kafka"; URL="http://localhost:9092"; Test="nc -z localhost 9092"},
    @{Name="ClickHouse"; URL="http://localhost:8123"; Test="curl -s http://localhost:8123/?query=SELECT%201"},
    @{Name="Kafka Connect"; URL="http://localhost:8083"; Test="curl -s http://localhost:8083/connectors"},
    @{Name="Grafana"; URL="http://localhost:3000"; Test="curl -s http://localhost:3000/api/health"},
    @{Name="Prometheus"; URL="http://localhost:9090"; Test="curl -s http://localhost:9090/-/ready"}
)

foreach ($service in $services) {
    try {
        if ($service.Name -eq "PostgreSQL") {
            $result = Test-NetConnection -ComputerName localhost -Port 5432 -WarningAction SilentlyContinue
            if ($result.TcpTestSucceeded) { Write-Host "✅ $($service.Name): OK" -ForegroundColor Green }
            else { Write-Host "❌ $($service.Name): FAILED" -ForegroundColor Red }
        } elseif ($service.Name -eq "Kafka") {
            $result = Test-NetConnection -ComputerName localhost -Port 9092 -WarningAction SilentlyContinue  
            if ($result.TcpTestSucceeded) { Write-Host "✅ $($service.Name): OK" -ForegroundColor Green }
            else { Write-Host "❌ $($service.Name): FAILED" -ForegroundColor Red }
        } else {
            $response = Invoke-WebRequest -Uri $service.URL -Method Get -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) { Write-Host "✅ $($service.Name): OK" -ForegroundColor Green }
            else { Write-Host "⚠️ $($service.Name): HTTP $($response.StatusCode)" -ForegroundColor Yellow }
        }
    } catch {
        Write-Host "❌ $($service.Name): FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. CDC Pipeline Status
Write-Host "`n3. CDC PIPELINE STATUS:" -ForegroundColor Yellow
try {
    $connectorStatus = curl -s http://localhost:8083/connectors/inventory-connector/status | ConvertFrom-Json
    Write-Host "✅ Debezium Connector: $($connectorStatus.connector.state)" -ForegroundColor Green
} catch {
    Write-Host "❌ Debezium Connector: NOT AVAILABLE" -ForegroundColor Red
}

# 4. Data Flow Check
Write-Host "`n4. DATA FLOW CHECK:" -ForegroundColor Yellow
try {
    $clickhouseQuery = 'SELECT count(*) as total_records, max(_synced_at) as last_sync FROM orders_final'
    $result = docker exec clickhouse clickhouse-client --query="$clickhouseQuery" 2>$null
    Write-Host "✅ ClickHouse Data: $result" -ForegroundColor Green
} catch {
    Write-Host "❌ ClickHouse Data: NOT AVAILABLE" -ForegroundColor Red
}

Write-Host "`n=== END HEALTH CHECK ===" -ForegroundColor Cyan
```

### Critical Path Diagnostic Decision Tree
```
🔍 Start Here → Is docker ps showing all 13 containers running?
                    ├─ NO → Go to "Container Startup Issues"
                    └─ YES → Is Debezium connector RUNNING?
                              ├─ NO → Go to "Debezium Connector Issues"
                              └─ YES → Is data appearing in ClickHouse?
                                      ├─ NO → Go to "Data Flow Issues"
                                      └─ YES → Go to "Performance Issues"
```

## 🐳 Container & Docker Issues

### Issue: Containers Won't Start or Keep Exiting

#### Quick Diagnosis
```powershell
# Check specific container logs
docker logs postgres-source --tail 50
docker logs kafka --tail 50
docker logs clickhouse --tail 50
docker logs kafka-connect --tail 50

# Check for port conflicts
netstat -an | findstr "5432 8123 9092 8083 3000 9090"

# Check Docker resources
docker system df
docker system events --since 10m
```

#### Common Causes & Solutions

**1. Port Conflicts**
```powershell
# Find processes using required ports
$ports = @(5432, 8123, 9092, 8083, 3000, 9090, 9100, 9187, 9308, 9116)
foreach ($port in $ports) {
    $process = netstat -ano | findstr ":$port "
    if ($process) {
        Write-Host "Port $port is in use:" -ForegroundColor Red
        Write-Host $process
        # Kill process if needed: taskkill /PID <PID> /F
    }
}
```

**2. Insufficient Memory**
```powershell
# Check available memory (need at least 8GB)
$memory = Get-ComputerInfo | Select-Object TotalPhysicalMemory, AvailablePhysicalMemory
$availableGB = [math]::Round($memory.AvailablePhysicalMemory / 1GB, 2)
Write-Host "Available Memory: $availableGB GB" -ForegroundColor $(if($availableGB -gt 8) {"Green"} else {"Red"})

# If low memory, restart Docker Desktop and close other applications
```

**3. Docker Desktop Issues**
```powershell
# Restart Docker Desktop
Write-Host "Restarting Docker Desktop..." -ForegroundColor Yellow
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Start-Sleep 5
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep 30

# Check if Docker is running
docker --version
docker info
```

**4. Volume/Permission Issues**
```powershell
# Clean up problematic volumes
docker-compose down -v
docker volume prune -f
docker system prune -f

# Restart with fresh volumes
docker-compose up -d
```

### Issue: Specific Container Failures

#### PostgreSQL Container Issues
```powershell
# Detailed PostgreSQL diagnostics
docker logs postgres-source --tail 100

# Common issues:
# - Data directory permissions
# - Invalid PostgreSQL configuration
# - Port already in use

# Solutions:
docker exec postgres-source pg_isready -U postgres
docker exec postgres-source psql -U postgres -c "\l"  # List databases
docker exec postgres-source psql -U postgres -d inventory -c "\dt"  # List tables
```

#### Kafka Container Issues
```powershell
# Kafka diagnostics
docker logs kafka --tail 100
docker logs zookeeper --tail 100

# Check Kafka topics
docker exec kafka kafka-topics.sh --bootstrap-server kafka:9092 --list

# Check Zookeeper connection
docker exec zookeeper zkCli.sh <<< "ls /"

# Common solutions:
# Restart Kafka after Zookeeper is fully ready
docker-compose restart zookeeper
Start-Sleep 30
docker-compose restart kafka
```

#### ClickHouse Container Issues
```powershell
# ClickHouse diagnostics
docker logs clickhouse --tail 100
docker logs clickhouse-keeper --tail 100

# Test ClickHouse connectivity
curl http://localhost:8123/?query=SELECT%201
docker exec clickhouse clickhouse-client --query="SELECT version()"

# Check ClickHouse system tables
docker exec clickhouse clickhouse-client --query="
SELECT * FROM system.tables WHERE database = 'default'"
```

## 🔗 Debezium & CDC Issues

### Issue: Debezium Connector Won't Start or Fails

#### Quick Connector Status Check
```powershell
# Check connector status
$connectorStatus = try {
    curl -s http://localhost:8083/connectors/inventory-connector/status | ConvertFrom-Json
} catch {
    Write-Host "❌ Kafka Connect not available" -ForegroundColor Red
    return
}

Write-Host "Connector State: $($connectorStatus.connector.state)" -ForegroundColor $(
    if($connectorStatus.connector.state -eq "RUNNING") {"Green"} else {"Red"})

if ($connectorStatus.tasks) {
    foreach ($task in $connectorStatus.tasks) {
        Write-Host "Task $($task.id): $($task.state)" -ForegroundColor $(
            if($task.state -eq "RUNNING") {"Green"} else {"Red"})
    }
}
```

#### Common Connector Issues

**1. Connector Registration Failed**
```bash
# Check if connector config is valid
curl -X POST http://localhost:8083/connector-plugins/io.debezium.connector.postgresql.PostgresConnector/config/validate \
  -H "Content-Type: application/json" \
  -d @config/debezium-source.json

# Re-register connector
curl -X DELETE http://localhost:8083/connectors/inventory-connector
curl -X POST http://localhost:8083/connectors/ \
  -H "Content-Type: application/json" \
  -d @config/debezium-source.json
```

**2. PostgreSQL Replication Issues**
```sql
-- Check PostgreSQL replication setup
-- Connect to PostgreSQL
docker exec -it postgres-source psql -U postgres -d inventory

-- Verify logical replication settings
SHOW wal_level;  -- Should be 'logical'
SHOW max_replication_slots;  -- Should be > 0
SHOW max_wal_senders;  -- Should be > 0

-- Check replication slots
SELECT slot_name, plugin, slot_type, database, active FROM pg_replication_slots;

-- Check publications
SELECT pubname, pubinsert, pubupdate, pubdelete FROM pg_publication;

-- If missing, create publication
CREATE PUBLICATION debezium_pub FOR TABLE inventory.orders;
```

**3. Connector Error Messages**

**Error**: "Replication slot 'debezium_slot' already exists"
```sql
-- Solution: Drop and recreate slot
SELECT pg_drop_replication_slot('debezium_slot');

-- Then restart connector
curl -X POST http://localhost:8083/connectors/inventory-connector/restart
```

**Error**: "Permission denied for schema inventory"
```sql
-- Solution: Grant proper permissions
GRANT USAGE ON SCHEMA inventory TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT SELECT ON TABLES TO postgres;
```

**Error**: "Could not find any server in the cluster"
```powershell
# Solution: Check network connectivity
docker exec kafka-connect nc -z kafka 9092
docker exec kafka-connect nc -z postgres-source 5432

# Restart containers in order
docker-compose restart zookeeper
Start-Sleep 30
docker-compose restart kafka
Start-Sleep 30
docker-compose restart kafka-connect
```

### Issue: High Connector Lag or Slow Processing

#### Diagnosis Commands
```powershell
# Check Kafka consumer lag
docker exec kafka kafka-consumer-groups.sh \
  --bootstrap-server kafka:9092 \
  --describe --group clickhouse_orders_group

# Check connector metrics
curl -s http://localhost:8083/connectors/inventory-connector/status | jq '.'

# Check PostgreSQL WAL generation
docker exec postgres-source psql -U postgres -d inventory -c "
SELECT pg_current_wal_lsn(), 
       pg_size_pretty(pg_current_wal_lsn() - '0/0') as wal_size;"
```

#### Performance Solutions
```json
// Optimize connector configuration
{
  "name": "inventory-connector",
  "config": {
    // ... existing config ...
    
    // Performance tuning
    "max.batch.size": "4096",
    "max.queue.size": "16384", 
    "poll.interval.ms": "500",
    "snapshot.fetch.size": "10240",
    
    // Reduce schema registry calls
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false"
  }
}
```

## 📊 ClickHouse & Data Issues

### Issue: No Data Appearing in ClickHouse

#### Systematic Data Flow Diagnosis
```sql
-- 1. Check if Kafka tables are receiving data
SELECT count(*) FROM orders_queue;  -- Should be > 0

-- 2. Check if materialized views are working
SELECT count(*) FROM orders_final;  -- Should match orders_queue

-- 3. Check recent data flow
SELECT 
    count(*) as total_records,
    min(_synced_at) as first_record,
    max(_synced_at) as last_record,
    now() - max(_synced_at) as lag_seconds
FROM orders_final;

-- 4. Check CDC operations distribution
SELECT operation, count(*) FROM orders_final GROUP BY operation;

-- 5. Check for parsing errors
SELECT count(*) FROM system.text_log 
WHERE event_time >= now() - INTERVAL 1 HOUR 
  AND level = 'Error' 
  AND message LIKE '%JSON%';
```

#### Common ClickHouse Data Issues

**1. Kafka Engine Not Consuming**
```sql
-- Check Kafka Engine settings
SELECT * FROM system.kafka_consumers;

-- Check system logs for Kafka errors
SELECT * FROM system.text_log 
WHERE event_time >= now() - INTERVAL 1 HOUR 
  AND message LIKE '%kafka%' 
ORDER BY event_time DESC LIMIT 50;

-- Restart Kafka tables if needed
DETACH TABLE orders_queue;
ATTACH TABLE orders_queue;
```

**2. Materialized View Issues**
```sql
-- Check materialized view status
SELECT database, table, engine 
FROM system.tables 
WHERE table LIKE '%_mv';

-- Check if MV is processing data
SELECT count(*) FROM orders_mv;  -- Should be 0 (it's a MV)

-- Drop and recreate materialized view if needed
DROP VIEW orders_mv;
-- Then recreate with proper JSON parsing
```

**3. JSON Parsing Errors**
```sql
-- Test JSON parsing manually
SELECT 
    raw_event,
    JSONExtractString(raw_event, 'payload', 'after', 'id') as parsed_id,
    JSONExtractString(raw_event, 'payload', 'op') as operation
FROM orders_queue 
LIMIT 5;

-- Check for null values in critical fields
SELECT 
    count(*) as total,
    countIf(JSONExtractString(raw_event, 'payload', 'after', 'id') IS NULL) as null_ids,
    countIf(JSONExtractString(raw_event, 'payload', 'op') IS NULL) as null_ops
FROM orders_queue;
```

### Issue: Slow ClickHouse Queries or High Memory Usage

#### Performance Diagnosis
```sql
-- Check running queries
SELECT 
    query_id,
    user,
    query,
    elapsed,
    memory_usage,
    read_rows,
    read_bytes
FROM system.processes;

-- Check query log for slow queries  
SELECT 
    query_duration_ms,
    query,
    memory_usage,
    read_rows,
    result_rows
FROM system.query_log 
WHERE event_time >= now() - INTERVAL 1 HOUR
  AND query_duration_ms > 5000
ORDER BY query_duration_ms DESC
LIMIT 10;

-- Check table sizes and parts
SELECT 
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows,
    count() as parts
FROM system.parts 
WHERE database = 'default'
GROUP BY table;
```

#### ClickHouse Performance Solutions
```sql
-- Optimize table structure (if needed)
ALTER TABLE orders_final 
    MODIFY COLUMN id UInt32 CODEC(DoubleDelta),
    MODIFY COLUMN order_date Date CODEC(DoubleDelta),
    MODIFY COLUMN total_amount Decimal64(2) CODEC(T64, ZSTD);

-- Force merge parts to reduce fragmentation
OPTIMIZE TABLE orders_final FINAL;

-- Update statistics
ANALYZE TABLE orders_final;
```

## 📈 Monitoring & Grafana Issues  

### Issue: Grafana Dashboard Shows "No Data"

#### Systematic Grafana Debugging
```powershell
# 1. Check Grafana connectivity
curl -s http://localhost:3000/api/health

# 2. Test data source connections
curl -u admin:admin http://localhost:3000/api/datasources
curl -u admin:admin http://localhost:3000/api/datasources/proxy/1/ping

# 3. Test ClickHouse queries directly
$query = "SELECT count(*) FROM orders_final"
curl "http://localhost:8123/?query=$([System.Web.HttpUtility]::UrlEncode($query))"

# 4. Check dashboard time range
# Dashboard may be looking at wrong time period
```

#### Common Grafana Issues

**1. Data Source Configuration Problems**
```bash
# Test ClickHouse connection from Grafana container
docker exec grafana wget -qO- "http://clickhouse:8123/?query=SELECT%201"

# Check if ClickHouse datasource is properly configured
docker exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml
```

**2. Query Syntax Issues**
```sql
-- Grafana ClickHouse queries should use proper time filtering
SELECT 
    toDateTime(toStartOfHour(_synced_at)) as time,
    count() as count
FROM orders_final 
WHERE _synced_at >= toDateTime('$__timeFrom') 
  AND _synced_at <= toDateTime('$__timeTo')
GROUP BY time 
ORDER BY time;

-- For Prometheus queries, use proper PromQL
rate(kafka_consumer_lag_sum[5m])
```

**3. Dashboard Import Issues**
```bash
# Check if dashboards are properly imported
curl -u admin:admin http://localhost:3000/api/search?type=dash-db

# Manually import dashboard if needed
curl -X POST -u admin:admin \
  http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana-config/dashboards/cdc-monitoring.json
```

### Issue: Prometheus Not Collecting Metrics

#### Prometheus Targets Diagnosis
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'

# Check specific exporter endpoints
curl -s http://localhost:9100/metrics | head  # Node exporter
curl -s http://localhost:9187/metrics | head  # PostgreSQL exporter  
curl -s http://localhost:9308/metrics | head  # Kafka exporter
curl -s http://localhost:9116/metrics | head  # ClickHouse exporter
```

#### Common Prometheus Issues

**1. Exporter Connection Issues**
```yaml
# Check if exporters are accessible from Prometheus container
services:
  prometheus:
    # Add debug environment
    environment:
      - PROMETHEUS_DEBUG=true
    # Check network connectivity
    networks:
      - cdc-network
```

**2. Configuration Syntax Errors**
```bash
# Validate Prometheus config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Check Prometheus logs
docker logs prometheus --tail 50
```

## 🔄 Data Consistency & Sync Issues

### Issue: Data Missing or Inconsistent

#### Complete Data Audit Process
```sql
-- 1. Count records in source (PostgreSQL)
SELECT count(*) as postgres_count FROM inventory.orders;

-- 2. Count records in target (ClickHouse) 
SELECT count(*) as clickhouse_count FROM orders_final;

-- 3. Check for duplicate records in ClickHouse
SELECT id, count(*) as occurrences 
FROM orders_final 
GROUP BY id 
HAVING count(*) > 1 
ORDER BY occurrences DESC 
LIMIT 10;

-- 4. Check CDC operation distribution
SELECT 
    operation,
    count(*) as count,
    min(_synced_at) as first_seen,
    max(_synced_at) as last_seen
FROM orders_final 
GROUP BY operation;

-- 5. Look for data gaps by time
SELECT 
    toStartOfHour(_synced_at) as hour,
    count(*) as records
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 24 HOUR
GROUP BY hour 
ORDER BY hour;
```

#### Data Consistency Solutions

**1. Resync Specific Time Period**
```sql
-- If data is missing for specific period, check Kafka retention
-- Kafka retains data for 7 days by default

-- Force reprocessing from Kafka (if data still available)
TRUNCATE TABLE orders_final;
DROP VIEW orders_mv;
-- Recreate materialized view (will reprocess all Kafka data)
-- Use setup script: .\scripts\setup.ps1
```

**2. Handle Duplicate Data**
```sql
-- Deduplicate using OPTIMIZE with FINAL
OPTIMIZE TABLE orders_final FINAL;

-- Or create a deduplication view
CREATE OR REPLACE VIEW orders_deduplicated AS
SELECT * FROM orders_final 
FINAL;  -- FINAL ensures latest version of each row
```

### Issue: High Sync Latency (>60 seconds)

#### Latency Analysis
```sql
-- Measure end-to-end latency
SELECT 
    avg(toUnixTimestamp(_synced_at) - source_ts_ms/1000) as avg_latency_seconds,
    max(toUnixTimestamp(_synced_at) - source_ts_ms/1000) as max_latency_seconds,
    min(toUnixTimestamp(_synced_at) - source_ts_ms/1000) as min_latency_seconds
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 1 HOUR;
```

#### Performance Optimization
```json
// Optimize Debezium connector for lower latency
{
  "name": "inventory-connector",
  "config": {
    // Reduce polling interval
    "poll.interval.ms": "100",
    
    // Increase batch size for efficiency  
    "max.batch.size": "2048",
    
    // Optimize heartbeat
    "heartbeat.interval.ms": "30000"
  }
}
```

```sql
-- Optimize ClickHouse Kafka settings for lower latency
ALTER TABLE orders_queue MODIFY SETTING 
  kafka_flush_interval_ms = 3000,  -- Flush more frequently
  kafka_max_block_size = 65536;    -- Smaller blocks for faster processing
```

## 🛠️ Advanced Debugging Tools

### Comprehensive Log Analysis Script
```powershell
# create-debug-report.ps1
param(
    [string]$OutputPath = ".\debug-report-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').txt"
)

Write-Host "Creating comprehensive debug report..." -ForegroundColor Yellow

# Redirect all output to file
Start-Transcript -Path $OutputPath

Write-Host "=== SYSTEM INFORMATION ===" -ForegroundColor Cyan
Get-ComputerInfo | Select-Object TotalPhysicalMemory, AvailablePhysicalMemory, CsProcessors
docker version
docker system df

Write-Host "`n=== CONTAINER STATUS ===" -ForegroundColor Cyan  
docker ps -a
docker-compose ps

Write-Host "`n=== CONTAINER LOGS (Last 50 lines each) ===" -ForegroundColor Cyan
$containers = @("postgres-source", "kafka", "kafka-connect", "clickhouse", "grafana", "prometheus")
foreach ($container in $containers) {
    Write-Host "`n--- $container ---" -ForegroundColor Yellow
    docker logs $container --tail 50 2>&1
}

Write-Host "`n=== NETWORK CONNECTIVITY ===" -ForegroundColor Cyan
$ports = @(5432, 8123, 9092, 8083, 3000, 9090, 9100, 9187, 9308, 9116)
foreach ($port in $ports) {
    $test = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
    Write-Host "Port $port : $($test.TcpTestSucceeded)" -ForegroundColor $(if($test.TcpTestSucceeded){"Green"}else{"Red"})
}

Write-Host "`n=== CDC PIPELINE STATUS ===" -ForegroundColor Cyan
try {
    $connectorStatus = curl -s http://localhost:8083/connectors/inventory-connector/status 2>$null
    Write-Host "Connector Status: $connectorStatus"
} catch {
    Write-Host "Failed to get connector status: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== DATA COUNTS ===" -ForegroundColor Cyan
try {
    $pgCount = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT count(*) FROM inventory.orders;" 2>$null
    Write-Host "PostgreSQL orders count: $pgCount"
} catch {
    Write-Host "Failed to get PostgreSQL count: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $chCount = docker exec clickhouse clickhouse-client --query="SELECT count(*) FROM orders_final" 2>$null
    Write-Host "ClickHouse orders count: $chCount"
} catch {
    Write-Host "Failed to get ClickHouse count: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-Transcript
Write-Host "`nDebug report saved to: $OutputPath" -ForegroundColor Green
```

### Performance Monitoring Script
```powershell
# monitor-performance.ps1
while ($true) {
    Clear-Host
    Write-Host "=== CDC PIPELINE PERFORMANCE MONITOR ===" -ForegroundColor Cyan
    Write-Host "$(Get-Date)" -ForegroundColor Yellow
    
    # Container resource usage
    Write-Host "`nCONTAINER RESOURCES:" -ForegroundColor Yellow
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | Select-Object -First 10
    
    # CDC metrics
    Write-Host "`nCDC METRICS:" -ForegroundColor Yellow
    try {
        $chLatency = docker exec clickhouse clickhouse-client --query="
        SELECT 
            count(*) as records_last_hour,
            avg(now() - _synced_at) as avg_lag_seconds
        FROM orders_final 
        WHERE _synced_at >= now() - INTERVAL 1 HOUR" 2>$null
        Write-Host "ClickHouse: $chLatency"
    } catch {
        Write-Host "ClickHouse: UNAVAILABLE" -ForegroundColor Red
    }
    
    Start-Sleep 30
}
```

---

## 📋 Troubleshooting Checklist

### Pre-Deployment Checklist
- [ ] **System Requirements**: 8GB+ RAM, Docker Desktop installed
- [ ] **Port Availability**: 5432, 8123, 9092, 8083, 3000, 9090, 9100, 9187, 9308, 9116
- [ ] **Network**: No corporate firewall blocking Docker networks
- [ ] **Resources**: At least 50% CPU and memory available

### Deployment Issues Checklist  
- [ ] **All containers running**: `docker ps` shows 13 containers in UP status
- [ ] **Services responding**: All health checks pass
- [ ] **Connector registered**: Debezium connector state = RUNNING
- [ ] **Topics created**: Kafka topics exist and accessible
- [ ] **Data flowing**: Records appearing in ClickHouse within 60 seconds

### Performance Issues Checklist
- [ ] **Resource utilization**: CPU < 80%, Memory < 80%
- [ ] **Sync latency**: End-to-end latency < 60 seconds  
- [ ] **Error rates**: No errors in container logs
- [ ] **Data consistency**: PostgreSQL and ClickHouse counts match
- [ ] **Monitoring working**: Grafana dashboards showing data

### Production Readiness Checklist
- [ ] **Monitoring configured**: All exporters and Prometheus working
- [ ] **Alerting setup**: Critical alerts configured
- [ ] **Backup strategy**: Regular backups scheduled
- [ ] **Documentation current**: All guides reflect actual configuration
- [ ] **Team trained**: Operations team familiar with troubleshooting

---

## 🆘 Getting Help

### Self-Service Resources
1. **Run Health Check**: Use the 30-second health check script above
2. **Check Logs**: Review specific container logs for error messages
3. **Verify Configuration**: Compare your setup with provided examples
4. **Test Components**: Use diagnostic commands for each service

### Escalation Path
1. **Create Debug Report**: Use the comprehensive debug report script
2. **Document Issue**: Include symptoms, error messages, and steps tried
3. **Share Configuration**: Provide docker-compose.yml and any customizations
4. **Include Logs**: Attach relevant container logs and system information

### Common Error Patterns
- **"Connection refused"**: Service not running or network issue
- **"Permission denied"**: Authentication or authorization problem  
- **"Out of memory"**: Insufficient system resources
- **"Port already in use"**: Another process using required port
- **"JSON parsing error"**: Malformed CDC events or schema issues

---

**🏠 [← Back to Main README](../README.md)** | **🏗️ [Architecture Guide](ARCHITECTURE.md)** | **⚙️ [Configuration →](CONFIGURATION.md)**

---

*This troubleshooting guide covers 95%+ of common issues. For complex problems, use the debug report script and escalation process.*

#### Prevention:
- Ensure 8GB+ RAM available
- Close unnecessary applications
- Use `docker-compose down -v` before restarting

---

### 🚨 **Issue 2: No Data in ClickHouse**

#### Symptoms:
- PostgreSQL has data, ClickHouse tables are empty
- CDC operations count is zero
- `monitor-cdc.ps1` shows no activity

#### Diagnostics:
```sql
-- Check if materialized views are active
docker exec clickhouse clickhouse-client --query "SELECT * FROM system.tables WHERE name LIKE '%_mv'"

-- Check ClickHouse Kafka engine status
docker exec clickhouse clickhouse-client --query "SELECT * FROM system.kafka_consumers"

-- Check data in final tables
docker exec clickhouse clickhouse-client --query "SELECT count(*) FROM orders_final"
docker exec clickhouse clickhouse-client --query "SELECT * FROM cdc_operations_summary"
```

#### Solutions:
```powershell
# 1. Check connector status
curl -s http://localhost:8083/connectors/postgres-source-connector/status

# 2. Restart ClickHouse Kafka consumers
docker exec clickhouse clickhouse-client --query "DETACH TABLE orders_kafka_json"
docker exec clickhouse clickhouse-client --query "ATTACH TABLE orders_kafka_json"

# 3. Check Kafka topics and messages
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic postgres-server.inventory.orders --from-beginning --max-messages 5

# 4. Re-setup ClickHouse tables
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery

# 5. Full pipeline restart
.\scripts\setup.ps1
```

---

### 🚨 **Issue 3: High Consumer Lag**

#### Symptoms:
- Data sync takes longer than 30 seconds
- `monitor-cdc.ps1` shows old timestamps
- Growing lag in Kafka consumers

#### Diagnostics:
```powershell
# Check consumer lag and status
.\scripts\cdc-monitor.ps1

# Check ClickHouse system tables
docker exec clickhouse clickhouse-client --query "
SELECT 
    name,
    status,
    last_exception
FROM system.kafka_consumers"

# Check recent sync timestamps
docker exec clickhouse clickhouse-client --query "
SELECT 
    'orders' as table,
    count() as count,
    max(_synced_at) as last_sync
FROM orders_final
UNION ALL
SELECT 
    'customers' as table,
    count() as count,
    max(_synced_at) as last_sync
FROM customers_final"
```

#### Solutions:
```powershell
# 1. Run performance test to generate load
.\scripts\cdc-stress-insert.ps1

# 2. Monitor pipeline after load
.\scripts\cdc-monitor.ps1

# 3. Restart ClickHouse Kafka consumers
docker exec clickhouse clickhouse-client --query "SYSTEM RESTART KAFKA"

# 4. Reset consumer group (will reprocess all data)
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --group clickhouse_orders_group --reset-offsets --to-latest --all-topics --execute
```

---

### 🚨 **Issue 4: Script Errors**

#### Symptoms:
- `setup.ps1` fails with PowerShell errors
- Permission denied errors
- "Cannot connect to Docker" errors

#### Solutions:
```powershell
# 1. Run PowerShell as Administrator
# Right-click PowerShell → "Run as Administrator"

# 2. Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 3. Check Docker connectivity
docker version
docker ps

# 4. Run scripts with explicit execution policy
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\cdc-monitor.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\cdc-stress-insert.ps1

# 5. Check PowerShell version (should be 5.1+)
$PSVersionTable.PSVersion
```

---

### 🚨 **Issue 5: Web Interfaces Not Accessible**

#### Symptoms:
- http://localhost:9001 (Kafdrop) not loading
- http://localhost:8123 (ClickHouse) connection refused
- Timeout errors in browser

#### Solutions:
```powershell
# 1. Check if services are running
docker ps | findstr "kafdrop\|clickhouse"

# 2. Check port binding
netstat -an | findstr "9001\|8123"

# 3. Test local connection
curl http://localhost:9001
curl http://localhost:8123

# 4. Windows Firewall (if needed)
# Windows Security → Firewall → Allow app
# Add Docker Desktop and your terminal

# 5. Restart problematic services
docker restart kafdrop
docker restart clickhouse
```

---

## Performance Issues

### 🐌 **Slow Performance**

#### Symptoms:
- Setup takes longer than 10 minutes
- High CPU/Memory usage
- System becomes unresponsive

#### Solutions:
```powershell
# 1. Increase Docker resources
# Docker Desktop → Settings → Resources
# Set Memory: 6GB+, CPU: 4+ cores

# 2. Use SSD storage
# Move Docker data to SSD drive

# 3. Close unnecessary applications
# Free up system resources

# 4. Check system requirements
systeminfo | findstr "Total Physical Memory"
# Need: 8GB+ total, 6GB+ available
```

### 📊 **Monitoring Performance**
```powershell
# Real-time resource monitoring during operations
docker stats --no-stream

# Use built-in monitoring script
.\scripts\cdc-monitor.ps1

# Check individual service performance
docker exec clickhouse clickhouse-client --query "
SELECT 
    name,
    value
FROM system.metrics 
WHERE name LIKE '%Query%' OR name LIKE '%Memory%'
LIMIT 10"

# Monitor CDC operations summary
docker exec clickhouse clickhouse-client --query "
SELECT * FROM cdc_operations_summary 
ORDER BY last_sync DESC"
```

---

## Error Patterns & Solutions

### 🔍 **Common Error Messages**

#### "Connection timeout after 30 seconds"
```powershell
# Wait longer for services to start
docker ps  # Check if containers are still starting
.\scripts\setup.ps1  # Re-run setup
```

#### "Connector already exists"
```powershell
# This is normal - setup script handles this automatically
# No action needed, setup will continue
```

#### "request returned 500 Internal Server Error"
```powershell
# ClickHouse not ready yet
docker logs clickhouse --tail 10
# Wait 1-2 minutes and try again
```

#### "The term './scripts/...' is not recognized"
```powershell
# Use full path or explicit execution
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
cd scripts
.\setup.ps1
``` 
WHERE event_time > now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC
LIMIT 10"
```

## Advanced Diagnostics

### Debug Kafka Messages
```powershell
# View raw Kafka messages
docker exec -it kafka-tools kafka-console-consumer --bootstrap-server kafka:9092 --topic postgres-server.inventory.orders --from-beginning --max-messages 5

# Check topic configuration
docker exec -it kafka-tools kafka-topics --bootstrap-server kafka:9092 --topic postgres-server.inventory.orders --describe
```

### Debug ClickHouse Processing
```sql
-- Check materialized view errors
SELECT * FROM system.errors WHERE name LIKE '%KAFKA%';

-- Check part merges
SELECT * FROM system.merges;

-- Check replication queue
SELECT * FROM system.replication_queue;
```

### Complete System Reset
```powershell
# Nuclear option - complete cleanup and restart
docker-compose down -v
docker system prune -a -f
docker volume prune -f
# Restart Docker Desktop
.\scripts\setup.ps1
```

## Getting Help

### Before Asking for Help:
1. ✅ Run diagnostic commands above
2. ✅ Check container logs for errors
3. ✅ Verify system requirements met
4. ✅ Try complete system reset

### Where to Get Help:
- 🐛 **GitHub Issues**: [Report bugs](https://github.com/Julio-analyst/debezium-cdc-mirroring/issues)
- 💬 **Discussions**: [Community help](https://github.com/Julio-analyst/debezium-cdc-mirroring/discussions)
- 📧 **Direct Contact**: [Julio's LinkedIn](https://www.linkedin.com/in/farrel-julio-427143288)

## Getting Help

### Before Asking for Help:
1. ✅ Run diagnostic commands above
2. ✅ Check container logs for errors
3. ✅ Verify system requirements met
4. ✅ Try complete system reset

### Where to Get Help:
- 🐛 **GitHub Issues**: [Report bugs](https://github.com/Julio-analyst/debezium-cdc-mirroring/issues)
- 💬 **Discussions**: [Community help](https://github.com/Julio-analyst/debezium-cdc-mirroring/discussions)
- 📧 **Direct Contact**: [Julio's LinkedIn](https://www.linkedin.com/in/farrel-julio-427143288)

### When Reporting Issues:
Please include:
- Operating system and version
- Docker Desktop version
- Error messages (full text)
- Output from diagnostic commands
- Steps to reproduce the problem

## Related Documentation
- ⚡ [Quick Start Guide](QUICK-START.md) - Basic setup help
- 📋 [Script Utilities](SCRIPT-UTILITIES.md) - Tool-specific issues
- 🏗️ [Technical Architecture](ARCHITECTURE.md) - Understanding the system
- ⚙️ [Configuration Guide](CONFIGURATION.md) - Advanced customization
- 🏛️ [Legacy Documentation](../README-LEGACY.md) - Complete technical reference

---
🏠 [← Back to Main README](../README.md) | ⚡ [Quick Start Guide](QUICK-START.md) | 🏗️ [Architecture →](ARCHITECTURE.md)
