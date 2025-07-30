# Perbandingan Cost dan Benefit Integrasi Data: CDC vs Pull vs Push

## 1. Ringkasan
Dokumen ini membandingkan tiga metode integrasi data antara PostgreSQL (source) dan ClickHouse (target) dalam satu server: CDC (Change Data Capture), Pull (Airflow ETL), dan Push (Message Broker + Backend Service). Analisis meliputi estimasi biaya, waktu setup, ROI, dan benefit bisnis berdasarkan data aktual dan referensi harga cloud.

---

## 2. Asumsi Dasar
- Sumber: PostgreSQL, Target: ClickHouse, satu server fisik/VM
- Volume data: 100 juta (100,000,000) record per bulan
- Resource log diambil dari hasil docker container (CPU, RAM, storage, network)
- Harga cloud: Contabo VPS, storage, dan bandwidth ([Contabo VPS Pricing](https://contabo.com/en/vps/))
- Upah engineer: $10/jam

---

## 3. Estimasi Resource & Cost Pipeline (100 Juta Data)
### a. Resource Usage (dari log)
- Peak CPU: ~4.34% dari 4 core VM (0.1736 core)
- Peak RAM: ~1GB
- Storage: 20GB (Kafka+ClickHouse, untuk 100jt data per bulan)
- Network: 10GB/bulan (estimasi transfer data antar service)

### b. Cloud Cost
- VM: 1 vCPU, 2GB RAM = $10/bulan
- Storage: 20GB × $0.10/GB = $2/bulan
- Network: 10GB × $0.12/GB = $1.2/bulan
- **Total Operasional:** $13.2/bulan

### c. Setup Cost
- CDC: 1 hari × $10/jam = $80
- Pull (Airflow): 2 hari × $10/jam = $160
- Push (Broker+Service): 3 hari × $10/jam = $240

---

## 4. Perbandingan Metode
| Metode      | VM Spec         | Biaya Bulanan | Setup Cost | Real-time | Maintenance | Kelebihan Utama         |
|-------------|-----------------|--------------|------------|-----------|-------------|-------------------------|
| CDC         | 1 vCPU, 2GB RAM | $13.2        | $80        | Ya        | Mudah       | Otomatis, audit, robust |
| Pull (ETL)  | 2 vCPU, 4GB RAM | $18.2        | $160       | Tidak     | Sedang      | Fleksibel, batch        |
| Push        | 2 vCPU, 4GB RAM | $18.2        | $240       | Ya        | Sulit       | Custom logic, flexible  |


### Rincian Cost per Metode

#### CDC (Change Data Capture)
- **VM:** 1 vCPU, 2GB RAM = $10/bulan ([Contabo VPS S](https://contabo.com/en/vps/))
- **Storage:** 20GB × $0.10/GB = $2/bulan
- **Network:** 10GB × $0.12/GB = $1.2/bulan
- **Setup engineering:** 1 hari × 8 jam × $10/jam = $80 (sekali di awal)
- **Maintenance:** Sangat minim, hanya update config jika ada perubahan besar (estimasi <1 jam/bulan, $10/bulan jika dihitung)
- **Software:** Open source (Debezium, Kafka, Kafka Connect, ClickHouse)
- **Total bulanan:** $13.2

#### Pull (Airflow ETL)
- **VM:** 2 vCPU, 4GB RAM = $15/bulan ([Contabo VPS M](https://contabo.com/en/vps/))
- **Storage:** 20GB × $0.10/GB = $2/bulan
- **Network:** 10GB × $0.12/GB = $1.2/bulan
- **Setup engineering:** 2 hari × 8 jam × $10/jam = $160 (sekali di awal)
- **Maintenance:** Update DAG, troubleshooting, monitoring job (estimasi 2 jam/bulan, $20/bulan)
- **Software:** Open source (Airflow, Python, ClickHouse)
- **Total bulanan:** $18.2

#### Push (Message Broker + Backend Service)
- **VM:** 2 vCPU, 4GB RAM = $15/bulan
- **Storage:** 20GB × $0.10/GB = $2/bulan
- **Network:** 10GB × $0.12/GB = $1.2/bulan
- **Setup engineering:** 3 hari × 8 jam × $10/jam = $240 (sekali di awal)
- **Maintenance:** Update backend service, monitoring, bugfix (estimasi 3 jam/bulan, $30/bulan)
- **Software:** Open source (RabbitMQ/NATS, backend service, ClickHouse)
- **Total bulanan:** $18.2

> **Catatan:**
> - Semua biaya setup adalah estimasi waktu kerja engineer × upah rata-rata ($10/jam, bisa disesuaikan).
> - Biaya maintenance dihitung jika ingin memperkirakan TCO (Total Cost of Ownership) jangka panjang.
> - Harga VM, storage, dan network diambil dari [Contabo VPS Pricing](https://contabo.com/en/vps/), bisa diganti sesuai provider.
> - Semua software yang digunakan open source (tidak ada lisensi komersial tambahan).

---

### Skema Perbandingan (Cost Setup & Maintenance Distandarkan)

Jika semua metode menggunakan biaya setup engineering $20 (sekali di awal) dan maintenance $15/bulan:

| Metode      | VM Spec         | Biaya Bulanan (VM+storage+network+maintenance) | Setup Cost | Real-time | Maintenance | Kelebihan Utama         |
|-------------|-----------------|-----------------------------------------------|------------|-----------|-------------|-------------------------|
| CDC         | 1 vCPU, 2GB RAM | $13.2 + $15 = $28.2                           | $20        | Ya        | Mudah       | Otomatis, audit, robust |
| Pull (ETL)  | 2 vCPU, 4GB RAM | $18.2 + $15 = $33.2                           | $20        | Tidak     | Sedang      | Fleksibel, batch        |
| Push        | 2 vCPU, 4GB RAM | $18.2 + $15 = $33.2                           | $20        | Ya        | Sulit       | Custom logic, flexible  |

> **Catatan:**
> - Skema ini memudahkan perbandingan jika perusahaan sudah punya standar biaya engineering/maintenance.
> - Komponen VM, storage, dan network tetap mengikuti kebutuhan masing-masing metode.
> - Maintenance tetap bisa berbeda secara effort, tapi cost diseragamkan untuk simulasi budgeting.

---

## 5. ROI & Benefit Bisnis
- **Otomatisasi:** Hemat waktu manual ETL ±40 jam/bulan ($400/bulan)
  - *Asumsi:* Sebelum otomatisasi, proses ETL manual (export-import, transformasi, validasi, dsb) memakan waktu 2 jam/hari × 20 hari kerja = 40 jam/bulan. Jika upah engineer $10/jam, maka penghematan waktu = 40 × $10 = $400/bulan.
- **ROI bulan pertama (CDC):**
  - ROI = (Benefit - Cost Operasional - Cost Setup) / (Cost Operasional + Cost Setup) × 100%
  - *Asumsi:* Benefit = $400/bulan (hemat waktu manual), Cost Operasional = $13.2 (VM, storage, network), Cost Setup = $80 (sekali di awal, 1 hari × 8 jam × $10/jam)
  - ROI = ($400 - $13.2 - $80) / ($13.2 + $80) × 100% ≈ 370%
- **Payback period:** $80 / ($400 - $13.2) ≈ 0.21 bulan (6 hari kerja)
  - *Asumsi:* Cost setup $80, penghematan bersih per bulan $400 - $13.2 = $386.8, sehingga payback period = $80 / $386.8 ≈ 0.21 bulan.
- **Benefit lain:** Real-time, audit trail, minim human error, downtime berkurang
  - *Asumsi:* Pipeline CDC berjalan otomatis, data selalu up-to-date, minim intervensi manual, dan mudah audit jika ada perubahan data.

---

## 6. Sumber & Referensi
- [Contabo VPS Pricing](https://contabo.com/en/vps/)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Google Cloud Compute Pricing](https://cloud.google.com/compute/all-pricing)
- [DigitalOcean Droplet Pricing](https://www.digitalocean.com/pricing)
- [RabbitMQ](https://www.rabbitmq.com/)
- [Apache Airflow](https://airflow.apache.org/)
- [Debezium](https://debezium.io/)
- [Airflow setup time & complexity](https://stackoverflow.com/questions/61385899/how-long-does-it-take-to-set-up-apache-airflow)
- [Astronomer Airflow best practices](https://www.astronomer.io/docs/cloud/stable/develop/airflow-best-practices/)
- [RabbitMQ tutorial & complexity](https://www.rabbitmq.com/tutorials/tutorial-one-python.html)
- [Dev.to: Real-time pipelines with PostgreSQL and RabbitMQ](https://dev.to/karanpratapsingh/real-time-data-pipelines-with-postgresql-and-rabbitmq-2e5g)
- [Debezium quickstart](https://debezium.io/documentation/reference/stable/tutorial.html)

---

## 7. Catatan
- Semua angka dapat disesuaikan dengan harga cloud dan upah engineer di perusahaan Anda.
- Untuk kebutuhan enterprise, tambahkan margin resource dan cost untuk high availability dan backup.
- Untuk perhitungan cost CRUD, network, dan storage lebih detail, gunakan statistik aktual dari pipeline dan harga provider.
