# ⚙️ Configuration Reference

All essential configurations for the CDC pipeline services.

## 🐳 Docker Compose Configuration

### Main Services Configuration

```yaml
# docker-compose.yml - Core Services
services:
  postgres-source:
    image: postgres:16.3
    environment:
      POSTGRES_DB: inventory
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    command: |
      postgres 
      -c wal_level=logical 
      -c max_replication_slots=10
      -c max_wal_senders=10
    ports:
      - "5432:5432"

  kafka:
    image: confluentinc/cp-kafka:latest
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    ports:
      - "9092:9092"

  kafka-connect:
    image: debezium/connect:2.6
    environment:
      BOOTSTRAP_SERVERS: kafka:9092
      GROUP_ID: 1
      CONFIG_STORAGE_TOPIC: connect_configs
      OFFSET_STORAGE_TOPIC: connect_offsets
      STATUS_STORAGE_TOPIC: connect_statuses
    ports:
      - "8083:8083"

  clickhouse:
    image: yandex/clickhouse-server:latest
    environment:
      CLICKHOUSE_DB: default
      CLICKHOUSE_USER: default
      CLICKHOUSE_PASSWORD: ""
    ports:
      - "8123:8123"
      - "9000:9000"
```

### Monitoring Stack Configuration

```yaml
# Monitoring Services
  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    volumes:
      - ./grafana-config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana-enterprise:latest
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_USERS_ALLOW_SIGN_UP: "false"
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-config/datasources:/etc/grafana/provisioning/datasources
      - ./grafana-config/dashboards:/etc/grafana/provisioning/dashboards
```

### Exporters Configuration

```yaml
# Metrics Exporters
  node-exporter:
    image: prom/node-exporter:latest
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@postgres-source:5432/inventory?sslmode=disable"
    ports:
      - "9187:9187"

  kafka-exporter:
    image: danielqsj/kafka-exporter:latest
    command:
      - '--kafka.server=kafka:9092'
    ports:
      - "9308:9308"

  clickhouse-exporter:
    image: f1yegor/clickhouse-exporter:latest
    environment:
      CLICKHOUSE_URL: "http://clickhouse:8123"
    ports:
      - "9116:9116"
```

## 📊 Service Configurations

### PostgreSQL Configuration

```sql
-- postgresql.conf key settings
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
shared_preload_libraries = 'pg_stat_statements'

-- Create replication user
CREATE ROLE debezium_user WITH REPLICATION LOGIN PASSWORD 'debezium';
GRANT CONNECT ON DATABASE inventory TO debezium_user;
GRANT USAGE ON SCHEMA inventory TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO debezium_user;

-- Create publication for CDC
CREATE PUBLICATION debezium_pub FOR TABLE inventory.orders;
```

### Kafka Configuration

```properties
# server.properties key settings
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Log settings
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Topic settings
num.partitions=3
default.replication.factor=1
min.insync.replicas=1
```

### ClickHouse Configuration

```xml
<!-- config.xml key settings -->
<clickhouse>
    <logger>
        <level>information</level>
    </logger>
    
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    
    <listen_host>0.0.0.0</listen_host>
    
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    
    <!-- Memory settings -->
    <max_memory_usage>10000000000</max_memory_usage>
    <use_uncompressed_cache>0</use_uncompressed_cache>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    
    <!-- Background tasks -->
    <background_pool_size>16</background_pool_size>
    <background_merges_mutations_concurrency_ratio>2</background_merges_mutations_concurrency_ratio>
</clickhouse>
```

### Debezium Connector Configuration

```json
{
  "name": "inventory-connector",
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "database.hostname": "postgres-source",
  "database.port": "5432",
  "database.user": "postgres", 
  "database.password": "postgres",
  "database.dbname": "inventory",
  "database.server.name": "postgres-server",
  "table.include.list": "inventory.orders",
  "plugin.name": "pgoutput",
  "slot.name": "debezium_slot",
  "publication.name": "debezium_pub",
  "topic.prefix": "postgres-server"
}
```

## 📊 Monitoring Configuration

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'kafka-exporter'
    static_configs:
      - targets: ['kafka-exporter:9308']

  - job_name: 'clickhouse-exporter'
    static_configs:
      - targets: ['clickhouse-exporter:9116']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

### Grafana Datasources

```yaml
# datasources.yml
apiVersion: 1

datasources:
  - name: ClickHouse
    type: clickhouse
    url: http://clickhouse:8123
    isDefault: true
    database: default
    basicAuth: false

  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: false

  - name: PostgreSQL
    type: postgres
    url: postgres-source:5432
    database: inventory
    user: postgres
    secureJsonData:
      password: postgres
```

### ClickHouse Database Setup

```sql
-- Create Kafka Engine table
CREATE TABLE orders_queue (
    raw_data String
) ENGINE = Kafka('kafka:9092', 'postgres-server.inventory.orders', 'clickhouse-group')
SETTINGS kafka_format = 'JSONAsString',
         kafka_num_consumers = 3,
         kafka_max_block_size = 1048576;

-- Create final storage table
CREATE TABLE orders_final (
    id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt16,
    product_id UInt32,
    operation String,
    _synced_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(order_date)
ORDER BY (id, _synced_at)
SETTINGS index_granularity = 8192;

-- Create materialized view
CREATE MATERIALIZED VIEW orders_mv TO orders_final AS
SELECT
    JSONExtractUInt(raw_data, 'after', 'id') as id,
    toDate(JSONExtractUInt(raw_data, 'after', 'order_date') + toDate('1970-01-01')) as order_date,
    JSONExtractUInt(raw_data, 'after', 'purchaser') as purchaser,
    JSONExtractUInt(raw_data, 'after', 'quantity') as quantity,
    JSONExtractUInt(raw_data, 'after', 'product_id') as product_id,
    JSONExtractString(raw_data, 'op') as operation,
    now() as _synced_at
FROM orders_queue
WHERE length(JSONExtractString(raw_data, 'after')) > 0;
```

## 🔧 Environment Variables

### Required Environment Variables

```bash
# PostgreSQL
POSTGRES_DB=inventory
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Kafka
KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9092

# ClickHouse  
CLICKHOUSE_DB=default
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=""

# Grafana
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin

# Exporters
DATA_SOURCE_NAME="postgresql://postgres:postgres@postgres-source:5432/inventory?sslmode=disable"
CLICKHOUSE_URL="http://clickhouse:8123"
```

### Optional Performance Tuning

```bash
# Kafka Performance
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_LOG_RETENTION_HOURS=168

# ClickHouse Performance
CLICKHOUSE_MAX_MEMORY_USAGE=10000000000
CLICKHOUSE_MAX_CONCURRENT_QUERIES=100
CLICKHOUSE_BACKGROUND_POOL_SIZE=16

# PostgreSQL Performance  
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=4MB
```

## 🔐 Security Configuration

### Network Security

```yaml
# Docker networks
networks:
  cdc-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

# Service network assignment
services:
  postgres-source:
    networks:
      - cdc-network
```

### Access Control

```sql
-- PostgreSQL users and permissions
CREATE ROLE readonly_user WITH LOGIN PASSWORD 'readonly_pass';
GRANT CONNECT ON DATABASE inventory TO readonly_user;
GRANT USAGE ON SCHEMA inventory TO readonly_user; 
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO readonly_user;

-- ClickHouse users
CREATE USER analytics_user IDENTIFIED BY 'analytics_pass';
GRANT SELECT ON default.* TO analytics_user;
```

### SSL/TLS Configuration

```yaml
# Enable SSL for PostgreSQL
postgres-source:
  command: |
    postgres 
    -c ssl=on
    -c ssl_cert_file=/etc/ssl/certs/server.crt
    -c ssl_key_file=/etc/ssl/private/server.key

# ClickHouse HTTPS
clickhouse:
  volumes:
    - ./certs:/etc/clickhouse-server/certs:ro
  environment:
    CLICKHOUSE_HTTPS_PORT: 8443
```

## 🎯 Performance Tuning

### High-Throughput Settings

```yaml
# Kafka high-throughput configuration
kafka:
  environment:
    KAFKA_BATCH_SIZE: 16384
    KAFKA_LINGER_MS: 100
    KAFKA_COMPRESSION_TYPE: snappy
    KAFKA_ACKS: 1

# ClickHouse optimization
clickhouse:
  environment:
    CLICKHOUSE_MAX_INSERT_BLOCK_SIZE: 1048576
    CLICKHOUSE_MIN_INSERT_BLOCK_SIZE_ROWS: 1048576
    CLICKHOUSE_MIN_INSERT_BLOCK_SIZE_BYTES: 268435456
```

### Resource Limits

```yaml
# Docker resource constraints
services:
  postgres-source:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G

  clickhouse:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
        reservations:
          cpus: '2.0'  
          memory: 4G
```

---

## Related Documentation
- 🚀 **[Step-by-Step Setup](STEP-BY-STEP-SETUP.md)** - Implementation guide
- 🏗️ **[Architecture](ARCHITECTURE.md)** - System design
- 🔧 **[Database Connection Troubleshooting](DATABASE-CONNECTION-TROUBLESHOOTING.md)** - Connection issues
- 📊 **[DBeaver Setup](DBEAVER-SETUP.md)** - Database GUI setup
- 🚀 **[Kafka Engine Explained](KAFKA-ENGINE-EXPLAINED.md)** - ClickHouse streaming