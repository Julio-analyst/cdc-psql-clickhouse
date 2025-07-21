# ⚡ Quick Start Guide (5 Minutes)

**Perfect for:** First-time users who want to see it working ASAP

## Prerequisites
- Windows 10+ with Docker Desktop installed
- 8GB RAM and 20GB free space
- 5 minutes of your time

## Step 1: Download & Setup
```powershell
# Download the project
git clone https://github.com/Julio-analyst/debezium-cdc-mirroring.git
cd debezium-cdc-mirroring/cdc-psql-clickhouse

# One command setup - grab a coffee! ☕
.\scripts\setup.ps1
```

## Step 2: Verify It's Working

After setup, you should see:
- 🟢 **8 services running** (check with: `docker ps`)
- 📊 **Sample data syncing** between databases  
- 🎛️ **Web interface** at http://localhost:9001
- ⚡ **Real-time updates** when you make changes

## Step 3: Test Real-time Sync

```sql
-- Add data to PostgreSQL (source)
docker exec -it postgres-source psql -U postgres -d inventory -c "
INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) 
VALUES ('2025-07-21', 1001, 5, 102);"

-- Check ClickHouse (target) - should appear in ~10 seconds
docker exec clickhouse clickhouse-client --query "
SELECT * FROM orders_final ORDER BY _synced_at DESC LIMIT 5 FORMAT PrettyCompact"
```

## Step 4: Monitor Real-time
```powershell
# Watch real-time changes
.\monitor-cdc.ps1

# Run a stress test (optional)
.\simple-stress-test.ps1
```

## Success Indicators ✅
- Data appears in ClickHouse within 10 seconds
- `monitor-cdc.ps1` shows operation counts
- Web UI at localhost:9001 shows flowing data
- No error messages in setup.ps1 output

## Next Steps
- 📊 [Business Benefits](BUSINESS-BENEFITS.md) - Why this matters for your business
- 🛠️ [Script Utilities](SCRIPT-UTILITIES.md) - Detailed tool explanations
- 🏗️ [Technical Architecture](ARCHITECTURE.md) - How it works under the hood
- 🔧 [Troubleshooting](TROUBLESHOOTING.md) - When things go wrong

## Related Documentation
- 📋 [Script Utilities Guide](SCRIPT-UTILITIES.md) - Understanding the automation tools
- ⚙️ [Configuration Guide](CONFIGURATION.md) - Advanced setup options
- 🏛️ [Legacy Documentation](../README-LEGACY.md) - Complete technical reference

---
🏠 [← Back to Main README](../README.md) | 📊 [Business Benefits →](BUSINESS-BENEFITS.md)
