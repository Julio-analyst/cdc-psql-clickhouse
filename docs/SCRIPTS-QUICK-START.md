# 🚀 Scripts Quick Reference Guide

> Panduan cepat penggunaan script untuk pipeline CDC PostgreSQL ke ClickHouse

---

## 📋 Daftar Script Utama

### 1. `setup.ps1` - Initial Pipeline Setup
### 2. `cdc-stress-insert.ps1` - Performance Testing
### 3. `cdc-monitor.ps1` - Pipeline Monitoring

---

## 🔧 Setup Awal

### Persiapan Environment
```powershell
# Set execution policy (jika diperlukan)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Pastikan Docker running
docker ps

# Pastikan semua container siap
docker compose ps
```

---

## 🚀 1. INITIAL SETUP

### Basic Usage
```powershell
# Setup lengkap pipeline CDC
.\scripts\setup.ps1
```

### Proses Yang Terjadi
1. **Container Startup** (30-60 detik): Docker menjalankan 8 container
2. **Health Check** (60-120 detik): Menunggu semua service siap
3. **Connector Registration** (10-30 detik): Mendaftarkan Debezium ke Kafka Connect
4. **ClickHouse Setup** (30-60 detik): Membuat tabel dan materialized view
5. **Data Verification** (10-20 detik): Memverifikasi sinkronisasi data awal

### Indikator Setup Berhasil
- ✅ **Output "Setup Complete!"**
- ✅ **Connector state: RUNNING**
- ✅ **Debezium topics created: 3**
- ✅ **Data counts > 0** untuk orders, customers, products

### Troubleshooting Setup
```powershell
# Jika ada container yang gagal start
docker compose down -v
docker compose up -d

# Cek status container
docker ps

# Cek log jika ada error
docker logs <container_name>
```

---

## 🎯 2. PERFORMANCE TESTING

### Basic Stress Test
```powershell
# Test default (1000 records, batch 100)
.\scripts\cdc-stress-insert.ps1
```

### Parameter Internal (dalam script)
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `Target Records` | 1000 | Jumlah total record |
| `Batch Size` | 100 | Record per batch |
| `Delay Between Batches` | 1s | Delay antar batch |

### Rekomendasi Skenario
- **Test Ringan**: Gunakan default (1000 records)
- **Test Standar**: Edit script untuk 2000-5000 records
- **Stress Test**: Edit script untuk 10000+ records
- **Debug Mode**: Monitor resource selama test berlangsung

### Interpretasi Hasil Test
| Metrik | Excellent | Good | Warning | Critical |
|--------|-----------|------|---------|----------|
| **Success Rate** | 100% | 100% | 95-99% | <95% |
| **Throughput** | >20 ops/sec | 10-20 ops/sec | 5-10 ops/sec | <5 ops/sec |
| **Avg Batch Time** | <1000ms | 1000-2000ms | 2000-5000ms | >5000ms |
| **Max Batch Time** | <2000ms | 2000-4000ms | 4000-8000ms | >8000ms |

### Lokasi Log Hasil
```
testing-results/
├── cdc-stress-test-[timestamp].log     # Detail test results
└── cdc-resource-usage-[timestamp].log  # Resource monitoring
```

---

## 📊 3. PIPELINE MONITORING

### Basic Usage
```powershell
# Monitoring lengkap (recommended)
.\scripts\cdc-monitor.ps1

# Monitoring sederhana (alternatif)
.\scripts\others\monitor-cdc.ps1
```

### Fitur Monitoring
- ✅ **Container Stats** - CPU, Memory, Network I/O semua service
- ✅ **Database Health** - PostgreSQL & ClickHouse connection test
- ✅ **Data Synchronization** - Perbandingan record count source vs target
- ✅ **Kafka Analysis** - Topics, consumer groups, messages
- ✅ **CDC Operations** - Connector status, replication analysis
- ✅ **WAL Monitoring** - PostgreSQL replication slots dan WAL
- ✅ **Performance Metrics** - Throughput, latency, success rate

### Interpretasi Output
| Metrik | Normal | Warning | Critical |
|--------|---------|---------|----------|
| **Container Health** | 8/8 healthy (100%) | 7/8 healthy | <7 healthy |
| **CPU Usage** | <20% | 20-50% | >50% |
| **Memory Usage** | <80% | 80-90% | >90% |
| **Response Time** | PostgreSQL <3s, ClickHouse <5s | 3-10s | >10s |
| **Sync Status** | SYNCHRONIZED | LAG <1000ms | LAG >1000ms |

### Timing Recommendations
```powershell
# Monitor setelah setup
.\scripts\setup.ps1
.\scripts\cdc-monitor.ps1

# Monitor setelah stress test
.\scripts\cdc-stress-insert.ps1
.\scripts\cdc-monitor.ps1

# Monitor berkala (harian/mingguan)
.\scripts\cdc-monitor.ps1
```

---

## 🎯 3. PERFORMANCE TESTING

### Basic Stress Test
```powershell
# Test default (1000 records, batch 100)
.\scripts\cdc-stress-insert.ps1
```

### Parameter Internal (dalam script)
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `Target Records` | 1000 | Jumlah total record |
| `Batch Size` | 100 | Record per batch |
| `Delay Between Batches` | 1s | Delay antar batch |

### Rekomendasi Skenario
- **Test Ringan**: Gunakan default (1000 records)
- **Test Standar**: Edit script untuk 2000-5000 records
- **Stress Test**: Edit script untuk 10000+ records
- **Debug Mode**: Monitor resource selama test berlangsung

### Interpretasi Hasil Test
| Metrik | Excellent | Good | Warning | Critical |
|--------|-----------|------|---------|----------|
| **Success Rate** | 100% | 100% | 95-99% | <95% |
| **Throughput** | >20 ops/sec | 10-20 ops/sec | 5-10 ops/sec | <5 ops/sec |
| **Avg Batch Time** | <1000ms | 1000-2000ms | 2000-5000ms | >5000ms |
| **Max Batch Time** | <2000ms | 2000-4000ms | 4000-8000ms | >8000ms |

### Lokasi Log Hasil
```
testing-results/
├── cdc-stress-test-[timestamp].log     # Detail test results
└── cdc-resource-usage-[timestamp].log  # Resource monitoring
```

---

## 🔧 3. CLICKHOUSE SETUP

### Manual SQL Execution
```powershell
# Eksekusi setup ClickHouse secara manual
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery
```

### Verifikasi Setup
```powershell
# Cek tabel yang dibuat
docker exec -i clickhouse clickhouse-client --query "SHOW TABLES"

# Cek data orders
docker exec -i clickhouse clickhouse-client --query "SELECT * FROM orders_final LIMIT 10"

# Cek summary CDC operations
docker exec -i clickhouse clickhouse-client --query "SELECT * FROM cdc_operations_summary FORMAT PrettyCompact"
```

---

## 🎯 Skenario Penggunaan

### Skenario 1: First Time Setup
```powershell
# 1. Setup awal lengkap
.\scripts\setup.ps1

# 2. Test performa
.\scripts\cdc-stress-insert.ps1

# 3. Verifikasi dengan monitoring
.\scripts\cdc-monitor.ps1
```

### Skenario 2: Daily Health Check
```powershell
# 1. Test performa baseline
.\scripts\cdc-stress-insert.ps1

# 2. Check status pipeline
.\scripts\cdc-monitor.ps1

# 3. Restart jika diperlukan
docker compose restart

# 4. Cleanup log lama (opsional)
Remove-Item .\testing-results\* -Include "*-$(Get-Date -Format 'yyyy-MM')*"
```

### Skenario 3: Performance Validation
```powershell
# 1. Run stress test
.\scripts\cdc-stress-insert.ps1

# 2. Monitor impact
.\scripts\cdc-monitor.ps1

# 3. Analyze logs
Get-ChildItem testing-results\ | Sort-Object LastWriteTime -Descending | Select-Object -First 2
```

### Skenario 4: Troubleshooting
```powershell
# 1. Run stress test untuk baseline
.\scripts\cdc-stress-insert.ps1

# 2. Cek status overall
.\scripts\cdc-monitor.ps1

# 3. Restart service bermasalah
docker compose restart <service_name>

# 4. Re-setup jika diperlukan
docker compose down -v
.\scripts\setup.ps1

# 5. Verifikasi perbaikan
.\scripts\cdc-monitor.ps1
```

---

## 📁 File Output & Log Analysis

### Lokasi File
```
testing-results/
├── cdc-stress-test-[timestamp].log          # Log detail insert test
├── cdc-resource-usage-[timestamp].log       # Log resource monitoring
└── [previous-test-logs...]
```

### Format Timestamp
- Format: `YYYY-MM-DD-HH-MM-SS`
- Contoh: `2025-09-02-22-57-21`

### Analisis Log
```powershell
# Lihat log terbaru
Get-ChildItem testing-results\ | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Baca log specific
Get-Content "testing-results\cdc-stress-test-2025-09-02-22-57-21.log"

# Cari pattern tertentu
Select-String -Path "testing-results\*.log" -Pattern "PERFORMANCE RESULTS"
```

---

## 🔍 Validasi & Verifikasi

### Cek Data PostgreSQL Source
```sql
-- Connect ke source database
docker exec -i postgres-source psql -U postgres -d inventory

-- Cek jumlah data
SELECT 'customers' as table_name, COUNT(*) as count FROM inventory.customers
UNION ALL
SELECT 'orders' as table_name, COUNT(*) as count FROM inventory.orders
UNION ALL
SELECT 'products' as table_name, COUNT(*) as count FROM inventory.products;
```

### Cek Data ClickHouse Target
```sql
-- Cek sinkronisasi di ClickHouse
docker exec -i clickhouse clickhouse-client --query "
SELECT 'customers_final' as table_name, COUNT(*) as count FROM customers_final
UNION ALL
SELECT 'orders_final' as table_name, COUNT(*) as count FROM orders_final
UNION ALL
SELECT 'products_final' as table_name, COUNT(*) as count FROM products_final"
```

### Cek Connector Status
```powershell
# Status Kafka Connect
curl http://localhost:8083/connectors

# Detail connector PostgreSQL source
curl http://localhost:8083/connectors/postgres-source-connector/status

# Cek Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

---

## ⚠️ Troubleshooting Cepat

### Script Tidak Bisa Dijalankan
```powershell
# Set policy sementara
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Set policy permanen
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Container Bermasalah
```powershell
# Cek status container
docker ps -a

# Restart specific container
docker restart postgres-source
docker restart clickhouse
docker restart kafka-connect

# Restart semua
docker compose restart
```

### Database Connection Error
```powershell
# Test koneksi PostgreSQL
docker exec -i postgres-source psql -U postgres -d inventory -c "SELECT 1;"

# Test koneksi ClickHouse
docker exec -i clickhouse clickhouse-client --query "SELECT 1"

# Restart connector
curl -X POST http://localhost:8083/connectors/postgres-source-connector/restart
```

### Performance Issues
- Monitor resource usage dengan `cdc-monitor.ps1`
- Restart container jika CPU/Memory tinggi
- Scale up resources jika bottleneck persisten
- Cek logs untuk error specific

---

## 💡 Tips & Best Practices

### 1. **Setup Strategy**
```powershell
# Selalu jalankan setup lengkap pertama kali
.\scripts\setup.ps1

# Verifikasi dengan monitoring
.\scripts\cdc-monitor.ps1

# Test performa untuk baseline
.\scripts\cdc-stress-insert.ps1
```

### 2. **Monitoring Strategy**
```powershell
# Pre-test monitoring (opsional)
.\scripts\cdc-monitor.ps1

# Execute test  
.\scripts\cdc-stress-insert.ps1

# Post-test analysis (wajib)
.\scripts\cdc-monitor.ps1
```

### 3. **Performance Optimization**
- **Baseline Test**: Jalankan stress test untuk mengukur performa normal
- **Resource Monitoring**: Monitor CPU/Memory usage secara berkala
- **Log Analysis**: Analisis pattern performa dari log files
- **Batch Size**: Optimal pada 100-200 record per batch untuk pipeline ini

### 4. **Maintenance Schedule**
- **Harian**: Quick monitoring dengan `cdc-monitor.ps1`
- **Mingguan**: Stress test untuk verifikasi performa
- **Bulanan**: Full cleanup dan log maintenance

### 5. **Log Management**
```powershell
# Cleanup log lama (>7 hari)
Get-ChildItem testing-results\ -Name "*.log" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | Remove-Item

# Archive log bulanan
$month = Get-Date -Format "yyyy-MM"
New-Item -ItemType Directory -Path "testing-results\archive\$month" -Force
Move-Item testing-results\*.log testing-results\archive\$month\
```

### 6. **Health Check Rutin**
- Jalankan monitoring sebelum dan sesudah test
- Cek sinkronisasi data secara berkala
- Monitor resource usage untuk mencegah bottleneck
- Validasi data integrity antara PostgreSQL dan ClickHouse

---

## 🎯 Quick Commands Cheat Sheet

```powershell
# SETUP COMMANDS
.\scripts\setup.ps1                                             # Complete pipeline setup
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery  # Manual ClickHouse setup

# TESTING
.\scripts\cdc-stress-insert.ps1                                # Performance testing

# MONITORING
.\scripts\cdc-monitor.ps1                                       # Full monitoring
.\scripts\others\monitor-cdc.ps1                               # Simple monitoring

# VALIDATION
curl http://localhost:8083/connectors                          # Check connectors
docker ps                                                      # Check containers
docker exec -i clickhouse clickhouse-client --query "SELECT * FROM cdc_operations_summary FORMAT PrettyCompact"  # CDC summary

# TROUBLESHOOT
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass     # Fix execution policy
docker compose restart                                         # Restart all services
docker compose down -v && docker compose up -d                 # Full restart with cleanup
curl -X POST http://localhost:8083/connectors/postgres-source-connector/restart  # Restart connector

# LOG ANALYSIS
Get-ChildItem testing-results\ | Sort-Object LastWriteTime -Descending | Select-Object -First 5  # Latest logs
Select-String -Path "testing-results\*.log" -Pattern "Success Rate"  # Search logs
```

---

**🔗 Referensi:**
- [Scripts Documentation](SCRIPTS-DOCUMENTATION.md) - Dokumentasi detail output dan analisis
- [Manual Setup](MANUAL-SETUP.md) - Panduan manual setup step-by-step
- [README.md](../README.md) - Setup dan overview project
