# Manual Setup CDC PostgreSQL to ClickHouse

Dokumen ini menjelaskan langkah-langkah manual untuk menjalankan pipeline CDC dari PostgreSQL ke ClickHouse menggunakan Docker, Kafka Connect, dan ClickHouse Kafka Engine.

## 1. Bersihkan Semua Container dan Volume
Jalankan perintah berikut untuk menghentikan dan menghapus semua container serta volume:
```powershell
docker compose down -v
```

## 2. Jalankan Semua Service
Mulai semua service dengan Docker Compose:
```powershell
docker compose up -d
```
Tunggu hingga semua container statusnya "healthy". Cek dengan:
```powershell
docker ps
```

## 3. Daftarkan Kafka Connector
Daftarkan connector Debezium ke Kafka Connect:
```powershell
Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method POST -ContentType "application/json" -Body (Get-Content .\config\debezium-source.json -Raw)
```
Pastikan respons sukses dan connector terdaftar.

## 4. Jalankan SQL untuk Membuat Kafka Engine di ClickHouse(tungggu 2 menit)
Eksekusi file SQL untuk membuat tabel, Kafka Engine, dan materialized view:
```powershell
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client
```
```powershell
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery
```
Pastikan tidak ada error dan semua objek berhasil dibuat.

## 5. Tes Insert Data ke PostgreSQL
Masukkan data ke tabel sumber di PostgreSQL, misal dengan psql, DBeaver, atau script insert.

## 6. Verifikasi Data di ClickHouse
Cek data yang sudah masuk ke ClickHouse:
```powershell
docker exec -i clickhouse clickhouse-client --query "SELECT * FROM orders_final LIMIT 10"
```
Atau cek ringkasan operasi CDC:
```powershell
docker exec -i clickhouse clickhouse-client --query "SELECT * FROM cdc_operations_summary LIMIT 10"
```

## 7. Pastikan Kafka Engine Sudah Aktif
Kafka Engine dibuat dengan SQL seperti berikut (pastikan sudah ada di file setup):
```sql
CREATE TABLE orders_kafka
(
    order_id UInt64,
    customer_id UInt64,
    product_id UInt64,
    order_date DateTime,
    amount Float64,
    operation_type String
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'dbserver1.public.orders',
         kafka_group_name = 'clickhouse_orders_consumer',
         kafka_format = 'JSONEachRow',
         kafka_num_consumers = 1;
```

## 8. Troubleshooting
- Pastikan semua container statusnya "healthy".
- Cek log Kafka Connect jika connector gagal terdaftar.
- Pastikan file SQL sudah dieksekusi tanpa error.
- Jika data tidak masuk ke ClickHouse, cek koneksi Kafka dan query materialized view.

---

Dokumen ini dapat digunakan sebagai panduan manual setup dan verifikasi pipeline CDC PostgreSQL → Kafka → ClickHouse.
