# 📚 CDC Pipeline Documentation

Complete documentation for PostgreSQL → Debezium → Kafka → ClickHouse CDC pipeline with Grafana monitoring.

## 🚀 Quick Start

**New to CDC?** Start here:
1. **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Complete setup guide from zero to working pipeline
2. **[Scripts Quick Start](SCRIPTS-QUICK-START.md)** - PowerShell scripts for setup and monitoring

## 📖 Core Documentation

### Setup & Configuration
- **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Complete installation and configuration guide
- **[Configuration Reference](CONFIGURATION.md)** - Detailed configuration options and parameters
- **[Architecture Overview](ARCHITECTURE.md)** - Technical architecture and data flow

### Tools & Integrations  
- **[DBeaver Setup](DBEAVER-SETUP.md)** - Database connection templates and SQL queries
- **[Grafana Setup](GRAFANA-SETUP.md)** - Dashboard configuration and monitoring setup

### Operations & Maintenance
- **[Scripts Guide](SCRIPTS-QUICK-START.md)** - PowerShell automation scripts (setup, monitoring, testing)
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

## 🎯 Documentation Goals

This documentation is designed to be:
- ✅ **Practical** - Focus on real-world implementation
- ✅ **Complete** - Cover all aspects from setup to production
- ✅ **Concise** - No unnecessary theory or marketing content
- ✅ **Up-to-date** - Maintained and tested configurations

## 🔄 Data Flow Overview

```
PostgreSQL → Debezium → Kafka → ClickHouse → Grafana
    ↓           ↓        ↓         ↓          ↓
  Source    CDC Capture Events  Analytics  Monitoring
```

## 📋 Project Structure

```
cdc-psql-clickhouse/
├── docs/              # 📚 This documentation
├── config/            # 🔧 Connector and database configurations  
├── scripts/           # 🚀 PowerShell automation scripts
├── clickhouse-config/ # 🗄️ ClickHouse server configuration
├── grafana-config/    # 📊 Grafana dashboards and data sources
├── plugins/           # 🔌 Debezium connector JAR files
└── docker-compose.yml # 🐳 Complete infrastructure stack
```

---

**Need help?** Start with [Step-by-Step Setup](STEP-BY-STEP-SETUP.md) or check [Troubleshooting](TROUBLESHOOTING.md) for common issues.