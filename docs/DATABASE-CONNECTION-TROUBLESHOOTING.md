# 🔧 Database Connection Troubleshooting

## 🚨 **Problem: Cannot Connect to PostgreSQL**

### Common Error Messages:
- `FATAL: password authentication failed for user 'postgres'`
- `Connection refused` 
- `Could not connect to server`
- `Port 5432 is already in use`

## 🔍 **Root Cause: Port Conflict**

Windows PostgreSQL service dan Docker PostgreSQL container mencoba menggunakan port 5432 yang sama.

### Quick Diagnosis:
```powershell
# Check what's using port 5432
netstat -ano | findstr :5432
```

## 🛠️ **SOLUTION 1: Stop Windows PostgreSQL Service**

### **Manual Method (Recommended):**

1. **Open Services Manager:**
   - Press `Windows + R`
   - Type `services.msc` 
   - Press Enter

2. **Find PostgreSQL Service:**
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