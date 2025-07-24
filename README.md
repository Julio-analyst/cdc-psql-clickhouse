# 🚀 Real-time Data Sync: PostgreSQL to ClickHouse


This project automatically copies every change from your main database (PostgreSQL) to your analytics database (ClickHouse) in **real-time** locally. 

> 💡 **In Simple Terms**: When someone places an order, updates their profile, or cancels a purchase - you'll see it in your analytics dashboard within 10 seconds, automatically.

## CDC Pipeline Overview

This CDC pipeline captures real-time data changes from PostgreSQL and MySQL using Debezium connectors, which stream updates to Kafka topics. Kafka acts as the event bus, while Kafka Connect manages data flow between connectors. Sink connectors then load the data into analytical targets like ClickHouse or other data warehouses via JDBC. This setup enables near real-time data replication for analytics without impacting source database performance.


## ⚡ Get Started in 5 Minutes

**Prerequisites**: Windows 10+ with Docker Desktop installed (8GB RAM recommended)

```powershell
# 1. Download the project
git clone https://github.com/Julio-analyst/cdc-psql-clickhouse.git
cd debezium-cdc-mirroring/cdc-psql-clickhouse
```
Clone the whole repository and lead it to the directory.

```
# 2. One command setup - grab a coffee! ☕
.\scripts\setup.ps1
```
This script automates the end-to-end CDC process from PostgreSQL → Kafka (via Debezium) → ClickHouse, including step-by-step validation and testing/debugging tools. It is highly useful for developers or data teams who want to simplify the real-time data synchronization process between systems.

```
# 3. Watch real-time changes
.\monitor-cdc.ps1
```
This script allows you to quickly view summary statistics and details about the data changes flowing from PostgreSQL → Kafka → ClickHouse via Debezium.


```
# 4. Analyze performance (optional)
.\statistics-performance.ps1
```
This script monitors the health and performance of a data pipeline that transfers changes from a PostgreSQL database to ClickHouse using Debezium and Kafka inside Docker containers. It checks how much memory and CPU are used during different operations like inserts and updates, evaluates the performance of each container (PostgreSQL, Kafka, ClickHouse, etc.), analyzes data throughput, disk I/O, network usage, query speed, and sync latency, and ensures all components are running properly.

```
# 5. Stress-test (optional)
.\simple-stress-test.ps1
```
This script is a simple stress test of a CDC (Change Data Capture) pipeline between PostgreSQL and ClickHouse, inserting 100,000 records into PostgreSQL in 100 batches of 1,000, then verifying that the changes replicate correctly to ClickHouse via CDC. At the end, it prints total time taken, throughput (records per second), final row counts in both systems, and a summary of how many create (c), update (u), and delete (d) operations were captured in ClickHouse.


**That's it!** You now have a complete real-time data pipeline running.

## ✅ Success Indicators

After setup, you should see:
- 🟢 **8 services running** (check with: `docker ps`)
- 📊 **Sample data syncing** between databases  
- 🎛️ **Web interface** at http://localhost:9001
- ⚡ **Real-time updates** when you make changes


### **Real-time Monitoring**
- **📊 Kafka UI**: http://localhost:9001 - See data flowing live
- **🗄️ ClickHouse**: http://localhost:8123 - Query your analytics database  
- **⚙️ Health Checks**: Automated monitoring and alerting

### **Performance Analytics**
- **🎯 Resource Utilization**: Real-time CPU, memory, and I/O monitoring
- **⚡ Throughput Metrics**: Operations per second, latency analysis
- **📊 Container Health**: Individual service performance tracking
- **💾 Storage Analytics**: Disk usage, query performance, sync latency

### **Automated Tools**
- **`setup.ps1`** - Complete pipeline deployment
- **`monitor-cdc.ps1`** - Real-time operation monitoring  
- **`statistics-performance.ps1`** - Comprehensive performance analysis & benchmarking
- **`simple-stress-test.ps1`** - Performance validation with 100K records

### **Production Ready**
- ✅ **5-10 second latency** end-to-end
- ✅ **100% reliability** tested with millions of operations
- ✅ **Zero impact** on your main database
- ✅ **Complete audit trail** of all changes

## 🚀 How It Works (Simple Version)

```
🏪 Your Business Database  →  🔄 Smart Bridge  →  📈 Analytics Database
   (PostgreSQL)              (Kafka + Debezium)     (ClickHouse)
   
   Every change is automatically copied in real-time!
```

## 👨‍💻 Credits

- **Author**: Asyraf

