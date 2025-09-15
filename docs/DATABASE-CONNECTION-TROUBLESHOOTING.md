# 🔧 Database Connection Troubleshooting Guide

**Perfect for:** Database connectivity issues, port conflicts, and connection setup problems

---
**🏠 [← Back to Main README](../README.md)** | **🔧 [Main Troubleshooting Guide](TROUBLESHOOTING.md)** | **⚙️ [Configuration →](CONFIGURATION.md)**

---

## 🚨 Common Database Connection Issues

### Issue 1: Cannot Connect to PostgreSQL

#### Symptoms & Error Messages:
- `FATAL: password authentication failed for user 'postgres'`
- `Connection refused on localhost:5432`
- `Could not connect to server: Connection refused`
- `Port 5432 is already in use`
- `psql: error: could not connect to server`

#### Root Cause Analysis:
The most common cause is **port conflict** - Windows PostgreSQL service and Docker PostgreSQL container both trying to use port 5432.

#### Quick Diagnosis Commands:
```powershell
# Check what's using port 5432
netstat -ano | findstr :5432

# Check if Windows PostgreSQL service is running
Get-Service -Name "postgresql*" | Format-Table -AutoSize

# Test Docker PostgreSQL connectivity
docker exec postgres-source pg_isready -U postgres -d inventory

# Check Docker PostgreSQL logs
docker logs postgres-source --tail 20
```

## 🛠️ Solution 1: Stop Windows PostgreSQL Service (Recommended)

### Manual Method:
1. **Open Services Manager:**
   ```powershell
   # Press Windows + R, type 'services.msc', press Enter
   ```

2. **Find and Stop PostgreSQL Service:**
   - Look for services named "postgresql-*" (e.g., "postgresql-x64-14")
   - Right-click → Stop
   - Right-click → Properties → Startup type: Disabled

3. **Verify Port is Free:**
   ```powershell
   netstat -ano | findstr :5432
   # Should return empty result
   ```

### PowerShell Method (Faster):
```powershell
# Stop all PostgreSQL services
Get-Service -Name "postgresql*" | Stop-Service -Force
Get-Service -Name "postgresql*" | Set-Service -StartupType Disabled

# Verify services are stopped
Get-Service -Name "postgresql*" | Format-Table -AutoSize
```

### Alternative Method - Kill Process by PID:
```powershell
# Find the process using port 5432
$process = netstat -ano | findstr :5432
Write-Host $process

# Kill the process (replace <PID> with actual PID)
taskkill /PID <PID> /F

# Example: If PID is 1234
# taskkill /PID 1234 /F
```

## 🛠️ Solution 2: Change Docker PostgreSQL Port

If you need to keep Windows PostgreSQL running, modify the Docker container port:

### Update docker-compose.yml:
```yaml
services:
  postgres-source:
    ports:
      - "5433:5432"  # Change host port to 5433
    # ... rest of configuration
```

### Update Connection Strings:
```bash
# DBeaver connection
Host: localhost
Port: 5433  # Changed from 5432
Database: inventory
Username: postgres
Password: postgres

# CLI connection
psql -h localhost -p 5433 -U postgres -d inventory
```

### Update Debezium Connector Config:
```json
{
  "name": "inventory-connector",
  "config": {
    "database.hostname": "postgres-source", 
    "database.port": "5432",  # Keep as 5432 (internal Docker port)
    // ... rest of config
  }
}
```

## 🔧 Issue 2: Cannot Connect to ClickHouse

#### Common Error Messages:
- `Connection refused on localhost:8123`
- `Code: 210. DB::NetException: Connection refused`
- `HTTP 500 Internal Server Error`
- `Authentication failed`

#### Diagnosis Commands:
```powershell
# Test HTTP connection
curl http://localhost:8123/?query=SELECT%201

# Test from inside Docker network
docker exec kafka curl http://clickhouse:8123/?query=SELECT%201

# Check ClickHouse logs
docker logs clickhouse --tail 30

# Check ClickHouse system status
docker exec clickhouse clickhouse-client --query="SELECT version(), uptime()"
```

#### Solutions:

**1. ClickHouse Container Not Ready:**
```powershell
# Wait for ClickHouse to fully start (can take 60+ seconds)
docker logs clickhouse -f  # Watch logs until "Ready for connections"

# Restart ClickHouse if needed
docker-compose restart clickhouse
```

**2. Port Conflict on 8123:**
```powershell
# Check what's using port 8123
netstat -ano | findstr :8123

# Kill conflicting process or change port in docker-compose.yml
```

**3. Authentication Issues:**
```sql
-- Connect as default user (no password)
docker exec clickhouse clickhouse-client --user=default

-- Check user configuration
docker exec clickhouse clickhouse-client --query="SELECT name, auth_type FROM system.users"
```

## 🔧 Issue 3: DBeaver Connection Problems

### PostgreSQL Connection in DBeaver:

#### Connection Settings:
```
Server Host: localhost
Port: 5432 (or 5433 if you changed it)
Database: inventory
Username: postgres
Password: postgres
```

#### Driver Configuration:
1. **Download PostgreSQL Driver:**
   - DBeaver → Database → Driver Manager → PostgreSQL
   - Download/Update driver if needed

2. **Test Connection:**
   - Click "Test Connection" before saving
   - Should show "Connected" with database info

#### Common DBeaver-PostgreSQL Issues:
```sql
-- If connection works but no tables visible:
-- Check schema permissions
\dt inventory.*

-- Grant proper permissions if needed
GRANT USAGE ON SCHEMA inventory TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO postgres;
```

### ClickHouse Connection in DBeaver:

#### Connection Settings:
```
Server Host: localhost
Port: 8123
Database: default
Username: default
Password: (leave empty)
```

#### Driver Selection:
- **Use ClickHouse driver** (not PostgreSQL)
- DBeaver → Database → New Database Connection → ClickHouse
- If not available, install ClickHouse plugin

#### Advanced ClickHouse Settings:
```
URL Template: http://localhost:8123/
Additional Properties:
  - use_server_time_zone: false
  - use_time_zone: UTC
  - socket_timeout: 30000
```

### DBeaver Query Testing:
```sql
-- Test PostgreSQL connection
SELECT COUNT(*) FROM inventory.orders;
SELECT * FROM inventory.orders LIMIT 10;

-- Test ClickHouse connection  
SELECT COUNT(*) FROM orders_final;
SELECT * FROM orders_final ORDER BY _synced_at DESC LIMIT 10;

-- Verify CDC sync is working
SELECT 
    (SELECT COUNT(*) FROM inventory.orders) as postgres_count,
    (SELECT COUNT(*) FROM default.orders_final) as clickhouse_count;
```

## 🔧 Issue 4: Network Connectivity Between Containers

### Internal Docker Network Issues:

#### Diagnosis:
```powershell
# Check Docker network
docker network ls | findstr cdc

# Inspect network details
docker network inspect cdc-network

# Test connectivity between containers
docker exec postgres-source nc -z kafka 9092
docker exec kafka nc -z clickhouse 8123
docker exec clickhouse nc -z postgres-source 5432
```

#### Common Network Problems:

**1. Containers Not in Same Network:**
```yaml
# Ensure all services use the same network
services:
  postgres-source:
    networks:
      - cdc-network
  kafka:
    networks:
      - cdc-network
  clickhouse:
    networks:
      - cdc-network

networks:
  cdc-network:
    driver: bridge
```

**2. Hostname Resolution Issues:**
```bash
# Test hostname resolution
docker exec postgres-source nslookup kafka
docker exec kafka nslookup clickhouse

# Use container names as hostnames, not localhost
# ✅ Good: kafka:9092
# ❌ Bad: localhost:9092 (from inside containers)
```

## 🔧 Issue 5: SSL/TLS Connection Issues

### PostgreSQL SSL Issues:

#### Disable SSL for Development:
```yaml
# In docker-compose.yml PostgreSQL command
command: |
  postgres
  -c ssl=off
  -c wal_level=logical
```

#### Or Configure SSL Properly:
```yaml
postgres-source:
  environment:
    POSTGRES_SSL_MODE: require
  volumes:
    - ./certs/postgres:/var/lib/postgresql/certs:ro
```

### ClickHouse HTTP vs HTTPS:

#### Use HTTP for Development:
```
ClickHouse URL: http://localhost:8123
Port: 8123 (HTTP)
```

#### Configure HTTPS for Production:
```xml
<!-- config.xml -->
<clickhouse>
    <https_port>8443</https_port>
    <tcp_port_secure>9440</tcp_port_secure>
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/certs/server.crt</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/certs/server.key</privateKeyFile>
        </server>
    </openSSL>
</clickhouse>
```

## 📋 Database Connection Checklist

### Pre-Connection Checklist:
- [ ] **Docker containers running**: All database containers show "Up" status
- [ ] **Ports available**: No conflicts on 5432, 8123, 9000
- [ ] **Network connectivity**: Containers can reach each other
- [ ] **Logs clean**: No error messages in container logs

### PostgreSQL Connection Checklist:
- [ ] **Port 5432 free**: Windows PostgreSQL service stopped
- [ ] **Container healthy**: `docker exec postgres-source pg_isready` succeeds
- [ ] **Database exists**: inventory database is created
- [ ] **Tables exist**: orders, customers, products tables present
- [ ] **Permissions set**: User has proper schema and table access

### ClickHouse Connection Checklist:
- [ ] **Port 8123 responding**: HTTP ping succeeds
- [ ] **Query works**: `SELECT 1` returns result
- [ ] **Tables exist**: Kafka tables and MergeTree tables created
- [ ] **Data flowing**: Recent records in orders_final table

### DBeaver Setup Checklist:
- [ ] **Drivers installed**: PostgreSQL and ClickHouse drivers current
- [ ] **Connections configured**: Correct hostnames, ports, credentials
- [ ] **Test connections**: Both connections show "Connected" status
- [ ] **Queries work**: Can run SELECT statements on both databases

## 🆘 Advanced Troubleshooting

### Complete Connection Reset:
```powershell
# Nuclear option - reset everything
docker-compose down -v
docker system prune -f
docker volume prune -f

# Stop any Windows services using the ports
Get-Service -Name "postgresql*" | Stop-Service -Force
netstat -ano | findstr ":5432 :8123 :9092" | ForEach-Object { 
    $pid = ($_ -split '\s+')[-1]
    if ($pid -ne "0") { taskkill /PID $pid /F }
}

# Restart Docker Desktop
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Start-Sleep 10
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Start-Sleep 60

# Start fresh
docker-compose up -d
```

### Connection Validation Script:
```powershell
# test-all-connections.ps1
Write-Host "=== DATABASE CONNECTION VALIDATION ===" -ForegroundColor Cyan

# Test PostgreSQL
try {
    $pgResult = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT 'PostgreSQL OK'"
    Write-Host "✅ PostgreSQL: $($pgResult.Trim())" -ForegroundColor Green
} catch {
    Write-Host "❌ PostgreSQL: FAILED" -ForegroundColor Red
}

# Test ClickHouse
try {
    $chResult = docker exec clickhouse clickhouse-client --query="SELECT 'ClickHouse OK'"
    Write-Host "✅ ClickHouse: $($chResult.Trim())" -ForegroundColor Green
} catch {
    Write-Host "❌ ClickHouse: FAILED" -ForegroundColor Red
}

# Test HTTP endpoints
$endpoints = @{
    "ClickHouse HTTP" = "http://localhost:8123/?query=SELECT%201"
    "Kafka Connect" = "http://localhost:8083/connectors"
    "Grafana" = "http://localhost:3000/api/health"
}

foreach ($endpoint in $endpoints.GetEnumerator()) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Value -Method Get -TimeoutSec 5 -UseBasicParsing
        Write-Host "✅ $($endpoint.Key): HTTP $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($endpoint.Key): FAILED" -ForegroundColor Red
    }
}

Write-Host "`n=== VALIDATION COMPLETE ===" -ForegroundColor Cyan
```

---

## Related Documentation
- 🔧 **[Main Troubleshooting Guide](TROUBLESHOOTING.md)** - Comprehensive problem solving
- 🗄️ **[DBeaver Setup Guide](DBEAVER-SETUP.md)** - Complete DBeaver configuration
- ⚙️ **[Configuration Guide](CONFIGURATION.md)** - All service configurations
- 🏗️ **[Architecture Guide](ARCHITECTURE.md)** - Understanding the system

---
**🏠 [← Back to Main README](../README.md)** | **🔧 [Main Troubleshooting Guide](TROUBLESHOOTING.md)** | **⚙️ [Configuration →](CONFIGURATION.md)**
   - Look for `postgresql-x64-16 - PostgreSQL Server 16` (or similar)
   - Right-click → `Stop`

3. **Disable Auto-Start (Optional):**
   - Right-click → `Properties`
   - Change `Startup type` to `Manual` or `Disabled`
   - Click `OK`

4. **Restart Docker Containers:**
   ```powershell
   docker-compose down
   docker-compose up -d
   ```

### **PowerShell Method (Advanced):**

```powershell
# Run PowerShell as Administrator
Stop-Service "postgresql-x64-16" -Force
Set-Service "postgresql-x64-16" -StartupType Manual

# Restart Docker containers
docker-compose down
docker-compose up -d
```

## 🛠️ **SOLUTION 2: Use Different Port**

If you need to keep Windows PostgreSQL running:

1. **Edit docker-compose.yml:**
   ```yaml
   postgres-source:
     ports:
       - "5433:5432"  # Change from 5432:5432
   ```

2. **Update Connection Settings:**
   ```
   Host: localhost
   Port: 5433  ← Use 5433 instead of 5432
   Database: inventory
   Username: postgres
   Password: postgres
   ```

## 🎯 **DBeaver Connection Settings**

### **Correct Configuration:**
```
🏠 Host: localhost
🔌 Port: 5432 (or 5433 if using Solution 2)
🗄️ Database: inventory
👤 Username: postgres
🔑 Password: postgres
☑️ Save password: Checked
```

### **Advanced Settings (if needed):**
- Tab `PostgreSQL` → ☑️ `Show all databases`
- Tab `Driver properties` → Add property:
  - Name: `ssl`
  - Value: `false`

## ✅ **Verify Connection Works**

### **Test with psql:**
```powershell
# Test Docker PostgreSQL
docker exec -it postgres-source psql -U postgres -d inventory -c "SELECT version();"
```

### **Test with DBeaver:**
1. Create new PostgreSQL connection
2. Use settings above
3. Click `Test Connection...`
4. Should show `Connected` message

## 🔍 **Advanced Troubleshooting**

### **Check Docker Container Status:**
```powershell
docker ps --filter "name=postgres-source"
```

### **Check PostgreSQL Logs:**
```powershell
docker logs postgres-source
```

### **Verify Port Availability:**
```powershell
# After stopping Windows PostgreSQL
netstat -ano | findstr :5432
# Should only show Docker container process
```

## ❌ **Common Mistakes**

1. **Forgetting to restart Docker** after stopping Windows PostgreSQL
2. **Using wrong database name** (use `inventory`, not `postgres`)
3. **Not running PowerShell as Administrator** for service commands
4. **Firewall blocking connection** (rare, but possible)

## 🆘 **Still Having Issues?**

### **Complete Reset:**
```powershell
# Stop everything
docker-compose down
Stop-Service "postgresql-x64-16" -Force

# Wait 10 seconds
Start-Sleep 10

# Start only Docker
docker-compose up -d

# Wait for services to be ready
Start-Sleep 30

# Test connection
docker exec -it postgres-source psql -U postgres -d inventory -c "\dt"
```

### **Verify Setup:**
After successful connection, you should see these tables in DBeaver:
- `customers`
- `orders` 
- `products`

---

**🎯 99% of PostgreSQL connection issues are resolved with Solution 1 (Stop Windows PostgreSQL Service)**