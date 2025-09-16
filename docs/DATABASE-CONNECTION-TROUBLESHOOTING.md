# 🔧 Database Connection Troubleshooting

Quick solutions for database connectivity issues.

## 🚨 Quick Diagnosis

### Check All Services
```powershell
# Container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Port conflicts
netstat -ano | findstr ":5432 :8123 :9092"

# Service health
docker exec postgres-source pg_isready -U postgres
docker exec clickhouse clickhouse-client --query "SELECT 1"
```

## 🔧 PostgreSQL Issues

### Issue: Cannot Connect to PostgreSQL

**Common Errors:**
- `Connection refused on localhost:5432`
- `Port 5432 is already in use`
- `password authentication failed`

**Root Cause:** Windows PostgreSQL service conflicts with Docker container

### Solution 1: Stop Windows Service (Recommended)
```powershell
# Stop PostgreSQL service
Get-Service -Name "postgresql*" | Stop-Service -Force
Get-Service -Name "postgresql*" | Set-Service -StartupType Disabled

# Verify port is free
netstat -ano | findstr :5432
```

### Solution 2: Change Docker Port
```yaml
# In docker-compose.yml
postgres-source:
  ports:
    - "5433:5432"  # Use different host port
```

### Solution 3: Kill Process
```powershell
# Find process using port 5432
$process = netstat -ano | findstr :5432
# Kill by PID (replace <PID> with actual PID)
taskkill /PID <PID> /F
```

### Test Connection
```powershell
# Test Docker PostgreSQL
docker exec postgres-source psql -U postgres -d inventory -c "SELECT version();"

# Test from host
psql -h localhost -p 5432 -U postgres -d inventory
```

## 🔧 ClickHouse Issues

### Issue: Cannot Connect to ClickHouse

**Common Errors:**
- `Connection refused on localhost:8123`
- `HTTP 500 Internal Server Error`
- `Authentication failed`

### Solution 1: Wait for Startup
```powershell
# ClickHouse takes 60+ seconds to start
docker logs clickhouse -f

# Wait for "Ready for connections" message
# Then test connection
curl http://localhost:8123/?query=SELECT%201
```

### Solution 2: Check Port Conflicts
```powershell
# Check what's using port 8123
netstat -ano | findstr :8123

# Restart ClickHouse if needed
docker-compose restart clickhouse
```

### Test Connection
```powershell
# HTTP test
curl http://localhost:8123/?query=SELECT%20version()

# Docker exec test  
docker exec clickhouse clickhouse-client --query="SELECT version(), uptime()"

# Check system tables
docker exec clickhouse clickhouse-client --query="SHOW TABLES"
```

## 🔧 DBeaver Connection Issues

### PostgreSQL Connection in DBeaver

**Settings:**
```
Host: localhost
Port: 5432 (or 5433 if changed)
Database: inventory
Username: postgres
Password: postgres
Driver: PostgreSQL
```

**Troubleshooting:**
1. **Test Connection** - Click "Test Connection" button
2. **Download Driver** - Update PostgreSQL driver if needed
3. **Check Schema** - Ensure `inventory` schema is visible

### ClickHouse Connection in DBeaver

**Settings:**
```
Host: localhost
Port: 8123
Database: default
Username: default
Password: (leave empty)
Driver: ClickHouse
```

**Troubleshooting:**
1. **Use HTTP Protocol** - Not HTTPS for local development
2. **Install ClickHouse Plugin** - If driver not available
3. **Check URL** - Should be `http://localhost:8123/`

### Common DBeaver Issues
```sql
-- Test queries
-- PostgreSQL
SELECT COUNT(*) FROM inventory.orders;

-- ClickHouse  
SELECT COUNT(*) FROM orders_final;

-- Verify CDC sync
SELECT 
    (SELECT COUNT(*) FROM inventory.orders) as postgres_count,
    (SELECT COUNT(*) FROM default.orders_final) as clickhouse_count;
```

## 🔧 Network Connectivity

### Container Network Issues

**Diagnosis:**
```powershell
# Check Docker network
docker network ls
docker network inspect cdc-network

# Test container connectivity
docker exec postgres-source nc -z kafka 9092
docker exec kafka nc -z clickhouse 8123
```

**Solutions:**
1. **Restart Containers:**
   ```powershell
   docker-compose down
   docker-compose up -d
   ```

2. **Check Network Configuration:**
   ```yaml
   # Ensure all services use same network
   services:
     postgres-source:
       networks: [cdc-network]
     kafka:
       networks: [cdc-network]
     clickhouse:
       networks: [cdc-network]
   ```

3. **Use Container Names:**
   - ✅ Good: `kafka:9092` (inside containers)
   - ❌ Bad: `localhost:9092` (inside containers)

## 🔧 Authentication Issues

### PostgreSQL Authentication
```sql
-- Check user permissions
\du
\l

-- Grant permissions if needed
GRANT CONNECT ON DATABASE inventory TO postgres;
GRANT USAGE ON SCHEMA inventory TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO postgres;
```

### ClickHouse Authentication
```sql
-- Connect as default user (no password)
docker exec clickhouse clickhouse-client --user=default

-- Check users
SELECT name, auth_type FROM system.users;
```

## 🔧 SSL/TLS Issues

### Disable SSL for Development
```yaml
# PostgreSQL - disable SSL
postgres-source:
  command: |
    postgres
    -c ssl=off
    -c wal_level=logical

# ClickHouse - use HTTP (not HTTPS)
# URL: http://localhost:8123 (not https)
```



## Related Documentation
- � **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Complete implementation guide
- 🗄️ **[DBeaver Setup](DBEAVER-SETUP.md)** - DBeaver configuration
- ⚙️ **[Configuration](CONFIGURATION.md)** - Service configurations
- 🏗️ **[Architecture](ARCHITECTURE.md)** - System design
- 🚀 **[Kafka Engine Explained](KAFKA-ENGINE-EXPLAINED.md)** - ClickHouse streaming