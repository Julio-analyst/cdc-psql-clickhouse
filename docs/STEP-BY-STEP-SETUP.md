# Step-by-Step Setup & Konfigurasi CDC PostgreSQL → ClickHouse

## 1. Prasyarat
- Windows 10+ dengan Docker Desktop (8GB RAM disarankan)
- DBeaver (untuk query SQL dan monitoring)

## 2. Clone Repository
```powershell
git clone https://github.com/Julio-analyst/cdc-psql-clickhouse.git
cd cdc-psql-clickhouse
```

## 3. Jalankan Semua Layanan
```powershell
docker-compose up -d
```

## 4. Konfigurasi Debezium Connector
Edit file `config/debezium-source.json` sesuai kebutuhan, contoh:
```json
{
  "name": "postgres-source-connector",
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "database.hostname": "postgres",
  "database.port": "5432",
  "database.user": "postgres",
  "database.password": "postgres",
  "database.dbname": "inventory",
  "database.server.name": "postgres-server",
  "plugin.name": "pgoutput",
  "slot.name": "debezium_slot",
  "publication.name": "debezium_pub",
  "table.include.list": "inventory.orders",
  "topic.prefix": "postgres-server"
}
```
- Register connector via Kafka Connect UI (`http://localhost:8001`) → Add Connection → Pilih PostgreSQL → Paste JSON di atas.

## 5. Setup Table di ClickHouse
- Buka DBeaver, connect ke ClickHouse (`localhost:8123`)
- Jalankan script `scripts/clickhouse-setup.sql` (hapus ORDER BY di akhir CREATE VIEW jika perlu)
- Pastikan table dan view sudah muncul di ClickHouse

## 6. Cek Data Real-time
- Insert/update/delete data di PostgreSQL (bisa via DBeaver)
- Cek data otomatis masuk ke table `orders_final` di ClickHouse
- Untuk summary operasi CDC:
```sql
SELECT * FROM cdc_operations_summary ORDER BY table_name, operation;
```

## 7. Monitoring & Troubleshooting
- Jalankan monitoring:
```powershell
./scripts/cdc-monitor.ps1
```
- Cek status container: `docker ps`
- Cek status connector: `curl http://localhost:8083/connectors`
- Cek log: `docker logs <container_name>`

## 8. Web UI
- Kafdrop: http://localhost:9001 (Kafka topics/messages)
- ClickHouse: http://localhost:8123 (Query interface)
- Portainer: https://localhost:9443 (Docker management)

---

**Catatan:**
- Untuk menambah table lain, update `table.include.list` di Debezium dan tambahkan table/VIEW di ClickHouse.
- Jika ada error pada CREATE VIEW, pastikan tidak ada ORDER BY di akhir definisi view.
