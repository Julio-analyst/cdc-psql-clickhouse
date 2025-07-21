# 📁 CDC Pipeline - File Analysis & Cleanup Report

## 🔍 **CORE FILES YANG DIGUNAKAN (ESSENTIAL)**

### **1. Docker Configuration** ✅
- `docker-compose.yml` - Main orchestration untuk local ClickHouse
- `docker-compose-external-ch.yml` - Untuk external ClickHouse (DEPRECATED)
- `.env` - Environment variables

### **2. ClickHouse Configuration** ✅
- `clickhouse-config/config.xml` - ClickHouse server config
- `clickhouse-config/users.xml` - ClickHouse users config  
- `clickhouse-config/keeper_config.xml` - ClickHouse Keeper config

### **3. Debezium Plugins** ✅
- `plugins/debezium-connector-postgres-2.6.0.Final.jar`
- `plugins/debezium-core-2.6.0.Final.jar`
- `plugins/debezium-api-2.6.0.Final.jar`
- `plugins/postgresql-42.6.1.jar`
- `plugins/protobuf-java-3.25.2.jar`

### **4. Kafka Connect Configuration** ✅
- `config/debezium-source.json` - Debezium connector config

### **5. Setup & Test Scripts** ✅
- `scripts/setup.ps1` - Main setup script
- `scripts/clickhouse-setup.sql` - ClickHouse tables setup
- `simple-stress-test.ps1` - Working stress test script

### **6. Documentation** ✅
- `README.md` - Main documentation

---

## 🗑️ **FILES YANG BISA DIHAPUS (CLEANUP)**

### **A. Duplicate/Old Stress Test Scripts** ❌
- `stress-test-100k.ps1` - Complex script, replaced by simple version
- `stress-test-100k-clean.ps1` - Duplicate functionality
- `test-external-clickhouse.ps1` - Old external test
- `setup-external-clickhouse.ps1` - Old external setup

### **B. Duplicate External ClickHouse Config** ❌
- `docker-compose-external-ch.yml` - Superseded by external-clickhouse-setup/
- `external-clickhouse.template.env` - Duplicate (ada di external-clickhouse-setup/)
- `config/debezium-orders-only.json` - Test config, not used
- `config/clickhouse-sink-external.json` - Moved to external-clickhouse-setup/

### **C. Old/Unused ClickHouse SQL Files** ❌
- `clickhouse-config/clickhouse-setup-complete.sql` - Old version
- `clickhouse-config/clickhouse-setup-working.sql` - Old version

### **D. Unused Scripts** ❌
- `scripts/test-cdc.ps1` - Basic test, replaced by stress test
- `scripts/setup.sh` - Linux version (PowerShell is primary)
- `scripts/start.ps1` - Not used in current workflow
- `scripts/stop.ps1` - Not used in current workflow

### **E. Documentation Files (Keep Some)** ⚠️
- `plugins/README*.md` - Debezium docs (can keep 1, remove others)
- `plugins/CHANGELOG.md` - Not essential
- `plugins/CONTRIBUTE.md` - Not essential
- `plugins/LICENSE*.txt` - Keep one, remove duplicates
- `plugins/COPYRIGHT.txt` - Can remove

### **F. Test Result Files** ❌
- `testing_result.md` - Old test results (2 duplicates)
- `testing-results.md` - Old test results

---

## 📊 **CLEANUP SUMMARY**

### **KEEP (Essential - 20 files)**
```
docker-compose.yml
.env
clickhouse-config/ (3 files)
plugins/ (5 JAR files + 1 LICENSE)
config/debezium-source.json
scripts/setup.ps1
scripts/clickhouse-setup.sql
simple-stress-test.ps1
README.md
external-clickhouse-setup/ (folder - 12 files)
```

### **DELETE (Non-essential - 29 files)**
- 4 old stress test scripts
- 4 duplicate config files  
- 2 old SQL files
- 4 unused scripts
- 8 documentation files
- 3 test result files
- 4 duplicate external configs

---

## 🎯 **RECOMMENDED ACTIONS**

### **Priority 1: Safe to Delete Immediately**
1. Remove duplicate stress test scripts
2. Remove old SQL setup files
3. Remove test result markdown files
4. Remove duplicate external configs

### **Priority 2: Review Before Delete**
1. Keep one README from plugins folder
2. Keep one LICENSE file
3. Review external-clickhouse-setup folder (might keep for future)

### **Final Structure (After Cleanup)**
```
cdc-psql-clickhouse/
├── docker-compose.yml
├── .env
├── README.md
├── simple-stress-test.ps1
├── clickhouse-config/
│   ├── config.xml
│   ├── users.xml
│   └── keeper_config.xml
├── plugins/
│   ├── debezium-connector-postgres-2.6.0.Final.jar
│   ├── debezium-core-2.6.0.Final.jar
│   ├── debezium-api-2.6.0.Final.jar
│   ├── postgresql-42.6.1.jar
│   ├── protobuf-java-3.25.2.jar
│   └── LICENSE.txt
├── config/
│   └── debezium-source.json
├── scripts/
│   ├── setup.ps1
│   └── clickhouse-setup.sql
└── external-clickhouse-setup/
    └── [complete external setup folder]
```

**Estimated size reduction: ~60% of files removed**
