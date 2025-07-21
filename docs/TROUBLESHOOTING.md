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
-- Check if Kafka consumers are running
docker exec clickhouse clickhouse-client --query "SELECT * FROM system.kafka_consumers"

-- Check raw Kafka consumption
docker exec clickhouse clickhouse-client --query "SELECT count(*) FROM orders_kafka_json"

-- Check materialized view
docker exec clickhouse clickhouse-client --query "SELECT count(*) FROM orders_final"
```

#### Solutions:
```powershell
# 1. Check connector status
curl -s http://localhost:8083/connectors/postgres-source-connector/status | ConvertFrom-Json

# 2. Restart Kafka consumers
docker exec clickhouse clickhouse-client --query "SYSTEM DROP KAFKA CONSUMERS"
docker exec clickhouse clickhouse-client --query "SYSTEM START KAFKA CONSUMERS"

# 3. Check Kafka topics
docker exec -it kafka-tools kafka-topics --bootstrap-server kafka:9092 --list

# 4. Re-register connector
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
# Check consumer lag
docker exec -it kafka-tools kafka-consumer-groups --bootstrap-server kafka:9092 --group clickhouse_orders_group --describe

# Check ClickHouse processing
docker exec clickhouse clickhouse-client --query "
SELECT 
    table,
    count() as messages,
    max(_synced_at) as last_sync
FROM (
    SELECT 'orders' as table, _synced_at FROM orders_final
    UNION ALL
    SELECT 'customers' as table, _synced_at FROM customers_final  
    UNION ALL
    SELECT 'products' as table, _synced_at FROM products_final
)
GROUP BY table"
```

#### Solutions:
```powershell
# 1. Increase ClickHouse memory
# Edit docker-compose.yml, increase clickhouse memory limit

# 2. Reset consumer offsets (CAUTION: Will reprocess all data)
docker exec -it kafka-tools kafka-consumer-groups --bootstrap-server kafka:9092 --group clickhouse_orders_group --reset-offsets --to-latest --all-topics --execute

# 3. Optimize ClickHouse settings
docker exec clickhouse clickhouse-client --query "
ALTER TABLE orders_final MODIFY SETTING 
    merge_with_ttl_timeout = 86400,
    max_part_loading_threads = 4"
```

---

### 🚨 **Issue 4: Script Errors**

#### Symptoms:
- `setup.ps1` fails with PowerShell errors
- Permission denied errors
- "Cannot connect to Docker" errors

#### Solutions:
```powershell
# 1. Run as Administrator
# Right-click PowerShell → "Run as Administrator"

# 2. Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Check Docker connectivity
docker version
docker info

# 4. Restart services manually
docker-compose down -v
docker-compose up -d --wait

# 5. Check PowerShell version
$PSVersionTable
# Should be 5.1+ or PowerShell Core 7+
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
# Real-time resource monitoring
docker stats

# Check individual service performance
docker exec clickhouse clickhouse-client --query "
SELECT 
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log 
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
