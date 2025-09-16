# 🚀 Real-time CDC Pipeline: PostgreSQL → Kafka → ClickHouse

**Enterprise-grade Change Data Capture with Native Streaming Analytics**

![CDC Pipeline Architecture](docs/coverpsql.png)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-Production%20Ready-green.svg)
![Version](https://img.shields.io/badge/version-3.0-brightgreen.svg)
![Tested](https://img.shields.io/badge/tested-100%25-success.svg)

> 💡 **Transform your PostgreSQL into a real-time analytics powerhouse!**  
> Stream database changes to ClickHouse in **< 10 seconds** using Debezium CDC + ClickHouse Kafka Engine.

---

## ⚡ 5-Minute Quick Start

### Prerequisites
- **System**: Windows 10+ with Docker Desktop
- **RAM**: 8GB minimum (12GB recommended)  
- **Ports**: 3000, 5432, 8001, 8083, 8123, 9000, 9001, 9090, 9443 available

### 🚀 Launch Full Stack
```powershell
# Clone repository
git clone https://github.com/Julio-analyst/cdc-psql-clickhouse-ui-enhanced.git
cd cdc-psql-clickhouse-ui-enhanced

# Start all services (17 containers)
docker-compose up -d

# Verify containers are running
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### 🔧 Setup CDC Pipeline
```powershell
# Setup ClickHouse tables automatically
.\scripts\setup.ps1

# Register Debezium connector
curl -X POST http://localhost:8083/connectors/ `
  -H "Content-Type: application/json" `
  -d '@config/debezium-source.json'
```

### ✅ Verify Real-time Sync
```sql
-- Insert test data (PostgreSQL)
docker exec -it postgres-source psql -U postgres -d inventory -c "
INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) 
VALUES (CURRENT_DATE, 1001, 5, 102);"

-- Check data synced (ClickHouse) - should appear within 10 seconds
docker exec -it clickhouse clickhouse-client --query "
SELECT id, purchaser, quantity, operation, _synced_at 
FROM orders_final ORDER BY _synced_at DESC LIMIT 5;"
```

**🎉 Success!** You now have real-time PostgreSQL → ClickHouse sync running!

---

## 📊 Web Interfaces

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Grafana Dashboard** | http://localhost:3000 | admin/admin | Analytics & Monitoring |
| **Kafka Connect UI** | http://localhost:8001 | - | CDC Connector Management |
| **Kafdrop** | http://localhost:9001 | - | Kafka Topics Monitor |
| **ClickHouse UI** | http://localhost:8123 | - | SQL Query Interface |
| **Prometheus** | http://localhost:9090 | - | Metrics Collection |
| **Portainer** | https://localhost:9443 | admin/admin | Docker Management |

---

## 🏗️ How It Works

```
📊 PostgreSQL     🔄 Debezium      🌊 Kafka       🚀 ClickHouse     📈 Grafana
   Source DB   →   CDC Engine   →   Stream     →   Analytics DB  →  Monitoring
   (OLTP)          (WAL Reader)     (Topics)       (OLAP)            (Dashboard)
                                      ↓
                                 📊 Prometheus
                                   (Metrics)
   
⚡ End-to-end latency: 5-10 seconds with zero impact on source database
```

### Core Components
- **PostgreSQL 16.3** - Source OLTP database with sample `inventory` data
- **Debezium 2.6** - Change Data Capture via Write-Ahead Log (WAL)
- **Apache Kafka** - Event streaming platform with 3 topics  
- **ClickHouse 24.3** - Target OLAP database with Kafka Engine
- **Monitoring Stack** - Grafana + Prometheus + 4 exporters

### Performance Results
- ✅ **Throughput**: 14-22 operations/second
- ✅ **Latency**: < 10 seconds PostgreSQL → ClickHouse
- ✅ **Success Rate**: 100% (no data loss)
- ✅ **Resource Usage**: < 20% CPU, < 1GB Memory

---

## 📁 Project Structure

```
cdc-psql-clickhouse-ui-enhanced/
├─ docker-compose.yml              # 17-service deployment
├─ scripts/
│   ├─ setup.ps1                  # Complete automation
│   ├─ cdc-monitor.ps1            # Real-time monitoring  
│   ├─ cdc-stress-insert.ps1      # Performance testing
│   └─ clickhouse-setup.sql       # Database schema
├─ config/
│   └─ debezium-source.json       # CDC connector config
├─ docs/                          # Documentation
├─ grafana-config/                # Pre-built dashboards
├─ clickhouse-config/             # ClickHouse settings
└─ testing-results/               # Auto-generated logs
```

---

## 🛠️ Management Scripts

### Performance Testing
```powershell
# Stress test with 1000 records
.\scripts\cdc-stress-insert.ps1

# Results: 14-22 ops/sec throughput logged to testing-results/
```

### Real-time Monitoring  
```powershell
# Comprehensive health check (11 sections)
.\scripts\cdc-monitor.ps1

# Covers: containers, databases, Kafka, CDC operations, resource usage
```

### Health Checks
```powershell
# Container status
docker ps

# Connector status  
curl http://localhost:8083/connectors

# CDC operations summary
docker exec -it clickhouse clickhouse-client --query "
SELECT * FROM cdc_operations_summary FORMAT PrettyCompact"
```

---

## 📚 Documentation

### Setup & Configuration
- **[📋 Step-by-Step Setup](docs/STEP-BY-STEP-SETUP.md)** - Complete implementation guide (includes detailed Grafana setup)
- **[⚙️ Configuration Reference](docs/CONFIGURATION.md)** - All service configurations  
- **[🗄️ DBeaver Setup](docs/DBEAVER-SETUP.md)** - Database connection templates

### Technical Deep Dive  
- **[🏗️ Architecture Overview](docs/ARCHITECTURE.md)** - System design & data flow
- **[🚀 Kafka Engine Explained](docs/KAFKA-ENGINE-EXPLAINED.md)** - ClickHouse streaming guide
- **[🔧 Database Connection Troubleshooting](docs/DATABASE-CONNECTION-TROUBLESHOOTING.md)** - Connection issues

---

## 🚨 Troubleshooting

### Common Issues

**Container Won't Start**
```powershell
# Check Docker Desktop running
docker version

# Check port conflicts
netstat -ano | findstr :5432

# Restart Docker Desktop if needed
```

**Connector Failed**  
```powershell
# Check connector status
curl http://localhost:8083/connectors/postgres-source-connector/status

# Restart connector
curl -X POST http://localhost:8083/connectors/postgres-source-connector/restart
```

**No Data in ClickHouse**
```sql
-- Check Kafka consumption
SELECT count(*) FROM orders_kafka_json;

-- Check materialized view processing  
SELECT count(*) FROM orders_final;

-- Manual refresh if needed
OPTIMIZE TABLE orders_final;
```

**Grafana No Data**
- **Time Range**: Change to "Last 7 days"
- **Data Source**: Verify ClickHouse connection in Settings
- **Query Test**: Use Explore → ClickHouse to test queries manually

---

## 💡 Business Benefits

### Real-time Analytics
- **📊 Instant Dashboards** - Revenue, orders, inventory in real-time
- **🔍 Live Monitoring** - Spot trends and issues within seconds  
- **⚡ Fast Decisions** - React to business changes immediately

### Technical Advantages
- **🎯 Zero Impact** - Source database performance unchanged
- **📈 Horizontal Scale** - Handle growing data volumes
- **🛡️ Fault Tolerant** - Built-in retry and health checks
- **🔧 Easy Maintenance** - Automated setup and monitoring

---

## 🎯 What's Included

### ✅ Complete Infrastructure
- **17 Docker containers** - All services ready to run
- **Pre-configured monitoring** - Grafana dashboards + Prometheus metrics
- **Sample data** - `inventory` database with orders, customers, products
- **Automated scripts** - Setup, monitoring, and performance testing

### ✅ Production Features  
- **Exactly-once semantics** - No duplicate or lost messages
- **Schema evolution support** - Handle database schema changes
- **Comprehensive logging** - All operations logged to `testing-results/`
- **Health monitoring** - Container, service, and CDC pipeline status

---

## 🚀 Ready to Start?

### For Beginners
1. **[📋 Step-by-Step Setup](docs/STEP-BY-STEP-SETUP.md)** - Follow the detailed guide
2. Run `.\scripts\setup.ps1` - Automated deployment  
3. Access http://localhost:3000 - See real-time dashboard

### For Experts
1. `docker-compose up -d` - Launch infrastructure
2. `.\scripts\cdc-monitor.ps1` - Validate deployment
3. `.\scripts\cdc-stress-insert.ps1` - Performance testing

---

## 💬 Support & Community

- **🐛 Issues**: [Report bugs](https://github.com/Julio-analyst/cdc-psql-clickhouse/issues)
- **💡 Ideas**: [Feature requests](https://github.com/Julio-analyst/cdc-psql-clickhouse/discussions)

---

**🎉 Transform your data architecture today!** Experience real-time PostgreSQL → ClickHouse analytics in 5 minutes.

