# 🔧 Troubleshooting Guide

**Perfect for:** When things go wrong and you need quick solutions

## Quick Diagnostic Commands

### Check System Health
```powershell
# Check all services status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check container logs
docker logs clickhouse --tail 20
docker logs kafka-connect --tail 20
docker logs postgres-source --tail 20

# Check system resources
docker system df
docker stats --no-stream
```

## Common Issues & Solutions

### 🚨 **Issue 1: Services Won't Start**

#### Symptoms:
- `docker ps` shows containers exiting
- Error messages about port conflicts
- Out of memory errors

#### Solutions:
```powershell
# Check port conflicts
netstat -an | findstr "5432 8123 9092 9001 8083"

# Free up resources
docker system prune -f
docker volume prune -f

# Restart Docker Desktop
# Right-click Docker Desktop → Restart

# Check available memory
systeminfo | findstr "Available Physical Memory"

# If ports are busy, kill processes:
netstat -ano | findstr ":5432"
taskkill /PID <PID_NUMBER> /F
```

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
