# ⚙️ Complete Configuration Reference

**Perfect for:** DevOps engineers, system administrators, and advanced users who need to customize and optimize the CDC pipeline

---
**🏠 [← Back to Main README](../README.md)** | **🏗️ [Architecture Guide](ARCHITECTURE.md)** | **🔧 [Troubleshooting →](TROUBLESHOOTING.md)**

---

## 📋 Configuration Overview

This guide covers all configuration aspects of the enterprise CDC pipeline including:
- **Container orchestration** (Docker Compose)
- **Service configurations** (PostgreSQL, Kafka, ClickHouse, Monitoring)
- **Network and security settings**
- **Performance tuning parameters**
- **Monitoring and alerting configuration**

## 🐳 Docker Compose Configuration

### ComFROM custom_table_kafka;
```

## 🚀 Performance Tuning & Optimization

### Production-Ready Performance Configuration

#### PostgreSQL Performance Tuning
```sql
-- postgresql.conf production settings
# === Memory Settings ===
shared_buffers = 2GB                    # 25% of system RAM
effective_cache_size = 6GB              # 75% of system RAM
work_mem = 128MB                        # Per-operation memory
maintenance_work_mem = 512MB            # VACUUM, CREATE INDEX memory
wal_buffers = 64MB                      # WAL buffer size

# === Checkpoint Settings ===  
checkpoint_timeout = 15min             # Maximum time between checkpoints
checkpoint_completion_target = 0.9     # Spread checkpoint I/O
max_wal_size = 2GB                     # Maximum WAL size before checkpoint
min_wal_size = 1GB                     # Minimum WAL size

# === Connection Settings ===
max_connections = 200                  # Connection limit
idle_in_transaction_session_timeout = 300000  # 5 minutes

# === Query Performance ===
random_page_cost = 1.1                # SSD-optimized
effective_io_concurrency = 200        # Concurrent I/O operations
max_worker_processes = 8              # Background workers
max_parallel_workers_per_gather = 4   # Parallel query workers

# === Logging for Monitoring ===
log_min_duration_statement = 1000     # Log slow queries (>1s)
log_lock_waits = on                   # Log lock waits
log_temp_files = 10240                # Log temp files >10MB
```

#### Kafka Production Tuning
```yaml
# kafka server.properties production settings
kafka:
  environment:
    # === Performance Settings ===
    KAFKA_NUM_NETWORK_THREADS: 16
    KAFKA_NUM_IO_THREADS: 16
    KAFKA_SOCKET_SEND_BUFFER_BYTES: 102400
    KAFKA_SOCKET_RECEIVE_BUFFER_BYTES: 102400
    KAFKA_SOCKET_REQUEST_MAX_BYTES: 104857600
    KAFKA_NUM_REPLICA_FETCHERS: 4
    
    # === Log Settings ===
    KAFKA_LOG_FLUSH_INTERVAL_MESSAGES: 10000
    KAFKA_LOG_FLUSH_INTERVAL_MS: 1000
    KAFKA_LOG_RETENTION_HOURS: 168        # 7 days
    KAFKA_LOG_RETENTION_BYTES: 1073741824 # 1GB per topic
    KAFKA_LOG_SEGMENT_BYTES: 536870912    # 512MB segments
    KAFKA_LOG_CLEANUP_POLICY: delete
    
    # === Replication Settings ===
    KAFKA_DEFAULT_REPLICATION_FACTOR: 3
    KAFKA_MIN_INSYNC_REPLICAS: 2
    KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: false
    
    # === JVM Settings ===
    KAFKA_HEAP_OPTS: "-Xmx4G -Xms4G"
    KAFKA_JVM_PERFORMANCE_OPTS: >
      -server
      -XX:+UseG1GC
      -XX:MaxGCPauseMillis=20
      -XX:InitiatingHeapOccupancyPercent=35
      -XX:+ExplicitGCInvokesConcurrent
      -XX:MaxInlineLevel=15
      -Djava.awt.headless=true
```

#### ClickHouse Production Configuration
```xml
<!-- config.xml production settings -->
<clickhouse>
    <!-- === Memory Configuration === -->
    <max_memory_usage>8000000000</max_memory_usage>        <!-- 8GB per query -->
    <max_memory_usage_for_user>16000000000</max_memory_usage_for_user> <!-- 16GB per user -->
    <max_server_memory_usage>24000000000</max_server_memory_usage>     <!-- 24GB total -->
    <max_concurrent_queries>200</max_concurrent_queries>
    
    <!-- === Background Processing === -->
    <background_pool_size>32</background_pool_size>
    <background_move_pool_size>16</background_move_pool_size>
    <background_schedule_pool_size>32</background_schedule_pool_size>
    <background_message_broker_schedule_pool_size>32</background_message_broker_schedule_pool_size>
    
    <!-- === Kafka Engine Optimization === -->
    <kafka>
        <auto_offset_reset>earliest</auto_offset_reset>
        <session_timeout_ms>30000</session_timeout_ms>
        <max_poll_interval_ms>300000</max_poll_interval_ms>
        <enable_auto_commit>true</enable_auto_commit>
        <auto_commit_interval_ms>5000</auto_commit_interval_ms>
        <fetch_min_bytes>1048576</fetch_min_bytes>       <!-- 1MB -->
        <fetch_max_bytes>52428800</fetch_max_bytes>      <!-- 50MB -->
        <max_partition_fetch_bytes>1048576</max_partition_fetch_bytes>  <!-- 1MB -->
        <debug>none</debug>
    </kafka>
    
    <!-- === MergeTree Optimization === -->
    <merge_tree>
        <max_suspicious_broken_parts>10</max_suspicious_broken_parts>
        <parts_to_delay_insert>300</parts_to_delay_insert>
        <parts_to_throw_insert>600</parts_to_throw_insert>
        <max_delay_to_insert>1</max_delay_to_insert>
        <max_parts_in_total>100000</max_parts_in_total>
        <merge_max_block_size>8192</merge_max_block_size>
        <max_bytes_to_merge_at_max_space_in_pool>161061273600</max_bytes_to_merge_at_max_space_in_pool>
    </merge_tree>
    
    <!-- === Query Optimization === -->
    <max_threads>16</max_threads>
    <max_insert_threads>8</max_insert_threads>
    <max_block_size>1048576</max_block_size>
    <min_insert_block_size_rows>1048576</min_insert_block_size_rows>
    <min_insert_block_size_bytes>268435456</min_insert_block_size_bytes>
</clickhouse>
```

### Advanced Container Resource Management
```yaml
# docker-compose production resource limits
version: '3.8'
services:
  postgres-source:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  kafka:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
        reservations:
          cpus: '2.0'
          memory: 4G
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  kafka-connect:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G

  clickhouse:
    deploy:
      resources:
        limits:
          cpus: '8.0'
          memory: 32G
        reservations:
          cpus: '4.0'
          memory: 16G
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

  prometheus:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 4G
        reservations:
          cpus: '0.5'
          memory: 2G

  grafana:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G
```

## 🔐 Advanced Security Configuration

### Production Security Hardening

#### Network Security
```yaml
# docker-compose security configuration
version: '3.8'
networks:
  backend-secure:
    driver: bridge
    internal: true
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
      com.docker.network.bridge.enable_ip_masquerade: "true"
    ipam:
      driver: default
      config:
        - subnet: 10.0.1.0/24
          gateway: 10.0.1.1

  frontend-secure:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
    ipam:
      driver: default
      config:
        - subnet: 10.0.2.0/24
          gateway: 10.0.2.1

services:
  postgres-source:
    networks:
      backend-secure:
        ipv4_address: 10.0.1.10
    security_opt:
      - no-new-privileges:true
      - apparmor:unconfined
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=100m
      - /var/run/postgresql:rw,noexec,nosuid,size=100m
    user: "999:999"  # postgres user
```

#### SSL/TLS Configuration
```yaml
# PostgreSQL SSL configuration
postgres-source:
  environment:
    POSTGRES_SSL_MODE: require
    POSTGRES_SSL_CERT_FILE: /var/lib/postgresql/server.crt
    POSTGRES_SSL_KEY_FILE: /var/lib/postgresql/server.key
    POSTGRES_SSL_CA_FILE: /var/lib/postgresql/ca.crt
  volumes:
    - ./certs/postgres:/var/lib/postgresql/certs:ro

# ClickHouse HTTPS configuration  
clickhouse:
  environment:
    CLICKHOUSE_HTTPS_PORT: 8443
    CLICKHOUSE_TCP_PORT_SECURE: 9440
  volumes:
    - ./certs/clickhouse:/etc/clickhouse-server/certs:ro
```

#### Authentication & Authorization
```sql
-- PostgreSQL security setup
-- Create dedicated CDC user with minimal privileges
CREATE ROLE debezium_cdc WITH LOGIN PASSWORD 'strong_random_password_123!';
GRANT CONNECT ON DATABASE inventory TO debezium_cdc;
GRANT USAGE ON SCHEMA inventory TO debezium_cdc;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO debezium_cdc;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA inventory TO debezium_cdc;

-- Grant replication privileges for Debezium
ALTER ROLE debezium_cdc WITH REPLICATION;

-- Create read-only user for monitoring
CREATE ROLE monitoring_reader WITH LOGIN PASSWORD 'monitoring_pass_456!';
GRANT CONNECT ON DATABASE inventory TO monitoring_reader;
GRANT USAGE ON SCHEMA inventory TO monitoring_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA inventory TO monitoring_reader;
```

```sql
-- ClickHouse security setup
-- Create analytics user with restricted access
CREATE USER analytics_user IDENTIFIED BY 'analytics_pass_789!';
CREATE QUOTA analytics_quota 
    FOR INTERVAL 1 HOUR MAX QUERIES 1000, MAX RESULT_ROWS 10000000;

GRANT SELECT ON default.orders_final TO analytics_user;
GRANT SELECT ON default.customers_final TO analytics_user;  
GRANT SELECT ON default.products_final TO analytics_user;
GRANT SHOW TABLES ON default.* TO analytics_user;
ALTER USER analytics_user SETTINGS max_memory_usage = 4000000000;
```

### Monitoring Security Configuration
```yaml
# Grafana security configuration
grafana:
  environment:
    # === Security Settings ===
    GF_SECURITY_ADMIN_PASSWORD: '${GRAFANA_ADMIN_PASSWORD}'
    GF_SECURITY_SECRET_KEY: '${GRAFANA_SECRET_KEY}'
    GF_SECURITY_DISABLE_GRAVATAR: "true"
    GF_SECURITY_COOKIE_SECURE: "true"
    GF_SECURITY_COOKIE_SAMESITE: "strict"
    GF_SECURITY_CONTENT_SECURITY_POLICY: "true"
    
    # === Authentication ===
    GF_AUTH_DISABLE_LOGIN_FORM: "false"
    GF_AUTH_DISABLE_SIGNOUT_MENU: "false"
    GF_USERS_ALLOW_SIGN_UP: "false"
    GF_USERS_ALLOW_ORG_CREATE: "false"
    GF_USERS_AUTO_ASSIGN_ORG: "true"
    GF_USERS_AUTO_ASSIGN_ORG_ROLE: "Viewer"
    
    # === Session Management ===
    GF_SESSION_PROVIDER: "memory"
    GF_SESSION_COOKIE_SECURE: "true"
    GF_SESSION_SESSION_LIFE_TIME: "3600"  # 1 hour
    
prometheus:
  command:
    - '--web.enable-admin-api=false'
    - '--web.enable-lifecycle=false'
    - '--storage.tsdb.retention.time=30d'
    - '--storage.tsdb.retention.size=50GB'
```

## 🎯 Environment-Specific Configuration

### Development Environment
```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  postgres-source:
    environment:
      POSTGRES_DB: inventory_dev
      POSTGRES_LOG_STATEMENT: all          # Verbose logging
      POSTGRES_LOG_MIN_DURATION: 0         # Log all queries
    volumes:
      - ./dev-data/postgres:/docker-entrypoint-initdb.d:ro

  kafka:
    environment:
      KAFKA_LOG_RETENTION_HOURS: 24        # Shorter retention
      KAFKA_HEAP_OPTS: "-Xmx512M -Xms512M" # Less memory
      KAFKA_LOG4J_ROOT_LOGLEVEL: DEBUG     # Verbose logging
      
  clickhouse:
    environment:
      CLICKHOUSE_LOG_LEVEL: debug          # Verbose logging
    volumes:
      - ./dev-data/clickhouse:/docker-entrypoint-initdb.d:ro

  grafana:
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin    # Simple password for dev
      GF_USERS_ALLOW_SIGN_UP: "true"       # Allow signups
      GF_INSTALL_PLUGINS: >
        grafana-clickhouse-datasource,
        grafana-clock-panel,
        grafana-worldmap-panel,
        grafana-piechart-panel
```

### Staging Environment  
```yaml
# docker-compose.staging.yml
version: '3.8'
services:
  postgres-source:
    environment:
      POSTGRES_DB: inventory_staging
      POSTGRES_SHARED_BUFFERS: 1GB
      POSTGRES_EFFECTIVE_CACHE_SIZE: 3GB
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G

  kafka:
    environment:
      KAFKA_HEAP_OPTS: "-Xmx2G -Xms2G"
      KAFKA_LOG_RETENTION_HOURS: 168       # 7 days
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G

  clickhouse:
    environment:
      CLICKHOUSE_MAX_MEMORY_USAGE: 4000000000  # 4GB
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G
```

### Production Environment
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  postgres-source:
    environment:
      POSTGRES_DB: inventory_production
      POSTGRES_SHARED_BUFFERS: 4GB
      POSTGRES_EFFECTIVE_CACHE_SIZE: 12GB
      POSTGRES_MAX_CONNECTIONS: 500
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 16G
        reservations:
          cpus: '2.0'
          memory: 8G
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  kafka:
    environment:
      KAFKA_HEAP_OPTS: "-Xmx8G -Xms8G"
      KAFKA_LOG_RETENTION_HOURS: 720        # 30 days
      KAFKA_NUM_PARTITIONS: 12
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
    deploy:
      resources:
        limits:
          cpus: '6.0'
          memory: 16G
        reservations:
          cpus: '3.0'
          memory: 8G
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  clickhouse:
    environment:
      CLICKHOUSE_MAX_MEMORY_USAGE: 16000000000  # 16GB
      CLICKHOUSE_MAX_SERVER_MEMORY_USAGE: 32000000000  # 32GB
    deploy:
      resources:
        limits:
          cpus: '12.0'
          memory: 64G
        reservations:
          cpus: '6.0'
          memory: 32G
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
```

## 🛠️ Operational Configuration & Automation

### Automated Backup Configuration
```bash
#!/bin/bash
# backup-configuration.sh

# === PostgreSQL Automated Backup ===
postgresql_backup() {
  BACKUP_DIR="/backups/postgres/$(date +%Y-%m-%d)"
  mkdir -p $BACKUP_DIR
  
  # Full database backup
  docker exec postgres-source pg_dump \
    -U postgres -d inventory \
    -f /tmp/inventory-backup-$(date +%Y%m%d-%H%M%S).sql
    
  # Copy backup to host
  docker cp postgres-source:/tmp/inventory-backup-$(date +%Y%m%d-%H%M%S).sql \
    $BACKUP_DIR/
    
  # WAL archive backup
  docker exec postgres-source tar -czf /tmp/wal-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
    /var/lib/postgresql/data/pg_wal/
    
  docker cp postgres-source:/tmp/wal-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
    $BACKUP_DIR/
}

# === ClickHouse Automated Backup ===
clickhouse_backup() {
  BACKUP_DIR="/backups/clickhouse/$(date +%Y-%m-%d)" 
  mkdir -p $BACKUP_DIR
  
  # Export all tables
  for table in orders_final customers_final products_final; do
    docker exec clickhouse clickhouse-client --query \
      "SELECT * FROM $table FORMAT CSVWithNames" > \
      $BACKUP_DIR/${table}-$(date +%Y%m%d-%H%M%S).csv
  done
  
  # Export table schemas
  docker exec clickhouse clickhouse-client --query \
    "SHOW CREATE TABLE orders_final" > \
    $BACKUP_DIR/schema-orders_final.sql
    
  docker exec clickhouse clickhouse-client --query \
    "SHOW CREATE TABLE customers_final" > \
    $BACKUP_DIR/schema-customers_final.sql
    
  docker exec clickhouse clickhouse-client --query \
    "SHOW CREATE TABLE products_final" > \
    $BACKUP_DIR/schema-products_final.sql
}

# === Kafka Topic Backup ===
kafka_backup() {
  BACKUP_DIR="/backups/kafka/$(date +%Y-%m-%d)"
  mkdir -p $BACKUP_DIR
  
  # Export topic configurations
  docker exec kafka kafka-configs.sh \
    --bootstrap-server kafka:9092 \
    --entity-type topics --describe > \
    $BACKUP_DIR/topic-configs-$(date +%Y%m%d-%H%M%S).txt
    
  # Export topic data (last 24 hours)
  docker exec kafka kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic postgres-server.inventory.orders \
    --from-beginning --timeout-ms 30000 > \
    $BACKUP_DIR/orders-topic-$(date +%Y%m%d-%H%M%S).json
}

# Schedule backups
case "$1" in
  "daily")
    postgresql_backup
    clickhouse_backup
    ;;
  "weekly") 
    postgresql_backup
    clickhouse_backup
    kafka_backup
    ;;
  *)
    echo "Usage: $0 {daily|weekly}"
    ;;
esac
```

### Health Check Configuration
```yaml
# Enhanced health checks in docker-compose.yml
services:
  postgres-source:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d inventory && psql -U postgres -d inventory -c 'SELECT 1;'"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  kafka:
    healthcheck:
      test: |
        kafka-topics --bootstrap-server kafka:9092 --list &&
        kafka-broker-api-versions --bootstrap-server kafka:9092
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  kafka-connect:
    healthcheck:
      test: |
        curl -f http://kafka-connect:8083/connectors &&
        curl -f http://kafka-connect:8083/connector-plugins
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

  clickhouse:
    healthcheck:
      test: |
        wget --no-verbose --tries=1 --spider http://clickhouse:8123/ping &&
        clickhouse-client --query "SELECT 1"
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  grafana:
    healthcheck:
      test: |
        curl -f http://grafana:3000/api/health &&
        curl -f http://grafana:3000/api/datasources
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  prometheus:
    healthcheck:
      test: |
        wget --no-verbose --tries=1 --spider http://prometheus:9090/-/healthy &&
        wget --no-verbose --tries=1 --spider http://prometheus:9090/api/v1/targets
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

## Related Documentation
- ⚡ [Quick Start Guide](STEP-BY-STEP-SETUP.md) - Get started first
- 🏗️ [Architecture Guide](ARCHITECTURE.md) - Understanding the system
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Fix configuration issues
- 📊 [Grafana Setup](GRAFANA-SETUP.md) - Dashboard configuration
- 💼 [Business Benefits](BUSINESS-BENEFITS.md) - ROI and value analysis

---
**🏠 [← Back to Main README](../README.md)** | **🏗️ [Architecture Guide](ARCHITECTURE.md)** | **🔧 [Troubleshooting →](TROUBLESHOOTING.md)**e Stack (docker-compose.yml)
```yaml
version: '3.8'

# Networks for service isolation
networks:
  cdc-network:
    driver: bridge
    name: cdc-network

# Persistent volumes for data storage
volumes:
  postgres_data:
    driver: local
  kafka_data:
    driver: local
  clickhouse_data:
    driver: local
  clickhouse_logs:
    driver: local
  grafana_data:
    driver: local
  prometheus_data:
    driver: local

services:
  # === CORE DATABASE SERVICES ===
  
  postgres-source:
    image: postgres:16.3
    hostname: postgres-source
    container_name: postgres-source
    environment:
      POSTGRES_DB: inventory
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-postgres.sql:/docker-entrypoint-initdb.d/init-postgres.sql:ro
    ports:
      - "5432:5432"
    command: |
      postgres
      -c wal_level=logical
      -c max_wal_senders=10
      -c max_replication_slots=10
      -c max_connections=200
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d inventory"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - cdc-network
    restart: unless-stopped

  # === EVENT STREAMING SERVICES ===
  
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    hostname: zookeeper
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_SYNC_LIMIT: 2
      ZOOKEEPER_INIT_LIMIT: 5
      ZOOKEEPER_MAX_CLIENT_CNXNS: 0
      ZOOKEEPER_AUTOPURGE_SNAP_RETAIN_COUNT: 3
      ZOOKEEPER_AUTOPURGE_PURGE_INTERVAL: 24
    volumes:
      - ./zookeeper/data:/var/lib/zookeeper/data
      - ./zookeeper/logs:/var/lib/zookeeper/log
    healthcheck:
      test: echo srvr | nc zookeeper 2181 || exit 1
      interval: 10s
      timeout: 5s
      retries: 3
    networks:
      - cdc-network
    restart: unless-stopped

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    hostname: kafka
    container_name: kafka
    depends_on:
      zookeeper:
        condition: service_healthy
    environment:
      # Broker Configuration
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9094
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,PLAINTEXT_HOST://0.0.0.0:9094
      
      # Topic Configuration
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
      KAFKA_DELETE_TOPIC_ENABLE: "true"
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 1
      KAFKA_MIN_INSYNC_REPLICAS: 1
      
      # Log Configuration
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_LOG_RETENTION_BYTES: 1073741824
      KAFKA_LOG_SEGMENT_BYTES: 1073741824
      KAFKA_LOG_CLEANUP_POLICY: delete
      
      # Performance Configuration
      KAFKA_NUM_NETWORK_THREADS: 8
      KAFKA_NUM_IO_THREADS: 8
      KAFKA_SOCKET_SEND_BUFFER_BYTES: 102400
      KAFKA_SOCKET_RECEIVE_BUFFER_BYTES: 102400
      KAFKA_SOCKET_REQUEST_MAX_BYTES: 104857600
      
      # JVM Configuration
      KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
      KAFKA_JVM_PERFORMANCE_OPTS: "-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -Djava.awt.headless=true"
      
      # Metrics Configuration
      KAFKA_JMX_PORT: 9101
      KAFKA_JMX_HOSTNAME: kafka
      KAFKA_METRIC_REPORTERS: io.confluent.metrics.reporter.ConfluentMetricsReporter
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka:9092
    volumes:
      - kafka_data:/var/lib/kafka/data
    ports:
      - "9094:9094"
      - "9101:9101"
    healthcheck:
      test: kafka-topics --bootstrap-server kafka:9092 --list
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - cdc-network
    restart: unless-stopped

  kafka-connect:
    image: confluentinc/cp-kafka-connect:7.5.0
    hostname: kafka-connect
    container_name: kafka-connect
    depends_on:
      kafka:
        condition: service_healthy
      postgres-source:
        condition: service_healthy
    environment:
      # Connect Configuration
      CONNECT_BOOTSTRAP_SERVERS: kafka:9092
      CONNECT_REST_ADVERTISED_HOST_NAME: kafka-connect
      CONNECT_REST_PORT: 8083
      CONNECT_GROUP_ID: connect-cluster
      CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
      CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
      CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
      
      # Topic Configuration
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
      
      # Serialization
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE: "false"
      CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: "false"
      
      # Internal Configuration
      CONNECT_INTERNAL_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_INTERNAL_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      
      # Plugin Configuration
      CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components,/usr/local/share/kafka/plugins"
      
      # JVM Configuration
      KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
      
      # Logging
      CONNECT_LOG4J_ROOT_LOGLEVEL: INFO
      CONNECT_LOG4J_LOGGERS: org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR
    volumes:
      - ./plugins:/usr/local/share/kafka/plugins:ro
    ports:
      - "8083:8083"
    healthcheck:
      test: curl -f http://kafka-connect:8083/connectors || exit 1
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - cdc-network
    restart: unless-stopped

  # === ANALYTICS DATABASE SERVICES ===
  
  clickhouse-keeper:
    image: yandex/clickhouse-keeper:23.3
    hostname: clickhouse-keeper
    container_name: clickhouse-keeper
    environment:
      KEEPER_ID: 1
    volumes:
      - ./clickhouse-config/keeper_config.xml:/etc/clickhouse-keeper/keeper_config.xml:ro
    ports:
      - "9181:9181"
    healthcheck:
      test: echo ruok | nc clickhouse-keeper 9181 || exit 1
      interval: 10s
      timeout: 5s
      retries: 3
    networks:
      - cdc-network
    restart: unless-stopped

  clickhouse:
    image: yandex/clickhouse-server:23.3
    hostname: clickhouse
    container_name: clickhouse
    depends_on:
      clickhouse-keeper:
        condition: service_healthy
      kafka:
        condition: service_healthy
    environment:
      CLICKHOUSE_DB: default
      CLICKHOUSE_USER: default
      CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: 1
    volumes:
      - clickhouse_data:/var/lib/clickhouse
      - clickhouse_logs:/var/log/clickhouse-server
      - ./clickhouse-config/config.xml:/etc/clickhouse-server/config.xml:ro
      - ./clickhouse-config/users.xml:/etc/clickhouse-server/users.xml:ro
    ports:
      - "8123:8123"
      - "9000:9000"
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://clickhouse:8123/ping || exit 1
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - cdc-network
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

  # === MONITORING SERVICES ===
  
  prometheus:
    image: prom/prometheus:v2.40.7
    hostname: prometheus
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--storage.tsdb.retention.size=10GB'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    volumes:
      - ./grafana-config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./grafana-config/prometheus/alert.rules.yml:/etc/prometheus/alert.rules.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - node-exporter
      - postgres-exporter
      - kafka-exporter
      - clickhouse-exporter

  grafana:
    image: grafana/grafana-enterprise:9.3.0
    hostname: grafana
    container_name: grafana
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_INSTALL_PLUGINS: "grafana-clickhouse-datasource,grafana-clock-panel,grafana-worldmap-panel"
      GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: "/etc/grafana/provisioning/dashboards/cdc-monitoring.json"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-config/datasources:/etc/grafana/provisioning/datasources:ro
      - ./grafana-config/dashboards:/etc/grafana/provisioning/dashboards:ro
    ports:
      - "3000:3000"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - prometheus
      - clickhouse

  # === EXPORTERS FOR METRICS ===
  
  node-exporter:
    image: prom/node-exporter:v1.3.1
    hostname: node-exporter
    container_name: node-exporter
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    networks:
      - cdc-network
    restart: unless-stopped

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:v0.11.1
    hostname: postgres-exporter
    container_name: postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@postgres-source:5432/inventory?sslmode=disable"
      PG_EXPORTER_EXTEND_QUERY_PATH: "/etc/postgres_exporter/queries.yaml"
    volumes:
      - ./grafana-config/postgres-exporter/queries.yaml:/etc/postgres_exporter/queries.yaml:ro
    ports:
      - "9187:9187"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - postgres-source

  kafka-exporter:
    image: danielqsj/kafka-exporter:v1.6.0
    hostname: kafka-exporter
    container_name: kafka-exporter
    command:
      - --kafka.server=kafka:9092
      - --topic.filter="postgres-server.*"
      - --group.filter=".*"
    ports:
      - "9308:9308"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - kafka

  clickhouse-exporter:
    image: f1yegor/clickhouse-exporter:v0.1.0
    hostname: clickhouse-exporter  
    container_name: clickhouse-exporter
    environment:
      CLICKHOUSE_URL: "http://clickhouse:8123/"
      CLICKHOUSE_USER: "default"
      CLICKHOUSE_PASSWORD: ""
    ports:
      - "9116:9116"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - clickhouse

  # === UI TOOLS ===
  
  kafdrop:
    image: obsidiandynamics/kafdrop:3.30.0
    hostname: kafdrop
    container_name: kafdrop
    environment:
      KAFKA_BROKERCONNECT: kafka:9092
      JVM_OPTS: "-Xms32M -Xmx64M"
      SERVER_SERVLET_CONTEXTPATH: "/"
    ports:
      - "9001:9000"
    networks:
      - cdc-network
    restart: unless-stopped
    depends_on:
      - kafka
```

## 🗄️ Database Configuration

### PostgreSQL Optimization (postgres-source)
```sql
-- postgresql.conf optimizations
shared_buffers = 256MB              -- 25% of available RAM
effective_cache_size = 1GB          -- 75% of available RAM  
maintenance_work_mem = 64MB         -- For VACUUM, CREATE INDEX
checkpoint_completion_target = 0.9  -- Spread checkpoint I/O
wal_buffers = 16MB                  -- WAL buffer size
random_page_cost = 1.1              -- SSD optimization

-- WAL and Replication Settings (Required for Debezium)
wal_level = logical                 -- Enable logical replication
max_wal_senders = 10               -- Number of WAL sender processes
max_replication_slots = 10         -- Number of replication slots
max_connections = 200              -- Connection limit

-- Logging Configuration
log_statement = 'mod'              -- Log modifications
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on               -- Log checkpoint activity
log_connections = on               -- Log connections
log_disconnections = on            -- Log disconnections
```

### ClickHouse Configuration (clickhouse/config.xml)
```xml
<clickhouse>
    <!-- Network Configuration -->
    <listen_host>0.0.0.0</listen_host>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    
    <!-- Memory Configuration -->
    <max_memory_usage>4000000000</max_memory_usage> <!-- 4GB -->
    <max_memory_usage_for_user>8000000000</max_memory_usage_for_user> <!-- 8GB -->
    <max_concurrent_queries>100</max_concurrent_queries>
    <max_server_memory_usage>12000000000</max_server_memory_usage> <!-- 12GB -->
    
    <!-- Storage Configuration -->
    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>
    
    <!-- Logging Configuration -->
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>
    
    <!-- Kafka Engine Configuration -->
    <kafka>
        <auto_offset_reset>earliest</auto_offset_reset>
        <session_timeout_ms>30000</session_timeout_ms>
        <max_poll_interval_ms>300000</max_poll_interval_ms>
        <debug>none</debug>
    </kafka>
    
    <!-- Keeper Configuration -->
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>1</server_id>
        <log_storage_path>/var/lib/clickhouse/coordination/log</log_storage_path>
        <snapshot_storage_path>/var/lib/clickhouse/coordination/snapshots</snapshot_storage_path>
        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <dead_session_check_period_ms>500</dead_session_check_period_ms>
            <heart_beat_interval_ms>500</heart_beat_interval_ms>
        </coordination_settings>
        <raft_configuration>
            <server>
                <id>1</id>
                <hostname>clickhouse-keeper</hostname>
                <port>9234</port>
            </server>
        </raft_configuration>
    </keeper_server>
    
    <!-- Performance Settings -->
    <merge_tree>
        <max_suspicious_broken_parts>5</max_suspicious_broken_parts>
        <parts_to_delay_insert>150</parts_to_delay_insert>
        <parts_to_throw_insert>300</parts_to_throw_insert>
        <max_delay_to_insert>1</max_delay_to_insert>
    </merge_tree>
    
    <!-- Background Processing -->
    <background_pool_size>16</background_pool_size>
    <background_move_pool_size>8</background_move_pool_size>
    <background_schedule_pool_size>16</background_schedule_pool_size>
    <background_message_broker_schedule_pool_size>16</background_message_broker_schedule_pool_size>
</clickhouse>
```

### ClickHouse Users Configuration (clickhouse/users.xml)
```xml
<clickhouse>
    <users>
        <!-- Default user for local connections -->
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
            <databases>
                <database>default</database>
            </databases>
        </default>
        
        <!-- Analytics user with restricted permissions -->
        <analytics>
            <password_sha256_hex>e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</password_sha256_hex>
            <networks>
                <ip>127.0.0.1</ip>
                <ip>172.20.0.0/16</ip>
            </networks>
            <profile>readonly</profile>
            <quota>default</quota>
            <databases>
                <database>default</database>
            </databases>
        </analytics>
    </users>
    
    <profiles>
        <!-- Default profile for admin operations -->
        <default>
            <max_memory_usage>4000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
            <max_concurrent_queries_for_user>450</max_concurrent_queries_for_user>
        </default>
        
        <!-- Read-only profile for analytics -->
        <readonly>
            <readonly>1</readonly>
            <max_memory_usage>2000000000</max_memory_usage>
            <max_execution_time>300</max_execution_time>
            <max_concurrent_queries_for_user>10</max_concurrent_queries_for_user>
            <use_uncompressed_cache>0</use_uncompressed_cache>
        </readonly>
    </profiles>
    
    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</clickhouse>
```
```sql
CREATE TABLE orders_kafka_json (
    payload String
) ENGINE = Kafka
SETTINGS 
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.orders',
    kafka_group_name = 'clickhouse_orders_group',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1;
```

## Script Configuration

### Automated Setup
For complete setup, use the provided scripts:
```powershell
# Complete pipeline setup
.\scripts\setup.ps1

# Performance testing
.\scripts\cdc-stress-insert.ps1

# Monitoring and health check
.\scripts\cdc-monitor.ps1
```

### Manual ClickHouse Setup
```powershell
# Execute ClickHouse setup SQL
Get-Content .\scripts\clickhouse-setup.sql | docker exec -i clickhouse clickhouse-client --multiquery
```

## Performance Tuning

### ClickHouse Optimization
```sql
-- Optimized final table structure
CREATE TABLE orders_final (
    order_id UInt32,
    order_date Date,
    purchaser UInt32,
    quantity UInt32,
    product_id UInt32,
    operation_type String,
    _synced_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (order_id, _synced_at)
SETTINGS 
    index_granularity = 8192;
```

### Stress Test Configuration
Edit script parameters in `.\scripts\cdc-stress-insert.ps1`:
```powershell
# Default configuration
$RecordCount = 1000      # Total records to insert
$BatchSize = 100         # Records per batch
$DelayBetweenBatches = 1 # Seconds between batches
```

### Kafka Optimization
```yaml
# Kafka settings in docker-compose.yml
environment:
  KAFKA_NUM_PARTITIONS: 1
  KAFKA_DEFAULT_REPLICATION_FACTOR: 1
  KAFKA_LOG_RETENTION_MS: 604800000  # 7 days
  KAFKA_LOG_SEGMENT_BYTES: 1073741824  # 1GB
  KAFKA_HEAP_OPTS: "-Xmx512M -Xms512M"
```

### Container Resource Limits
```yaml
# Resource optimization in docker-compose.yml
services:
  kafka-connect:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  
  clickhouse:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

## Security Configuration

### Basic Security
```yaml
# Docker security
security_opt:
  - no-new-privileges:true
read_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=100m
```

### Authentication
```xml
<!-- ClickHouse users.xml -->
<users>
  <cdc_user>
    <password>secure_password</password>
    <networks>
      <ip>172.20.0.0/16</ip>
    </networks>
    <profile>default</profile>
    <quota>default</quota>
  </cdc_user>
</users>
```

## Custom Table Setup

### Adding New Tables to CDC Pipeline
```sql
-- Add new table to CDC pipeline
CREATE TABLE custom_table_kafka (
    raw_message String
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'postgres-server.inventory.custom_table',
    kafka_group_name = 'clickhouse_custom_table_group',
    kafka_format = 'LineAsString';

-- Create target table
CREATE TABLE custom_table_final (
    id Int32,
    name String,
    created_at DateTime,
    operation String,
    _synced_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, _synced_at);

-- Create materialized view
CREATE MATERIALIZED VIEW custom_table_mv TO custom_table_final AS
SELECT 
    JSONExtractInt(raw_message, 'payload', 'after', 'id') as id,
    JSONExtractString(raw_message, 'payload', 'after', 'name') as name,
    parseDateTimeBestEffort(JSONExtractString(raw_message, 'payload', 'after', 'created_at')) as created_at,
    JSONExtractString(raw_message, 'payload', 'op') as operation,
    now() as _synced_at
FROM custom_table_kafka;
```

## Related Documentation
- ⚡ [Quick Start Guide](QUICK-START.md) - Get started first
- �️ [Architecture Guide](ARCHITECTURE.md) - Understanding the system
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Fix configuration issues
- 📋 [Script Utilities](SCRIPT-UTILITIES.md) - Automation tools
- 🏛️ [Legacy Documentation](../README-LEGACY.md) - Complete reference

---
�🏠 [← Back to Main README](../README.md) | 🏗️ [Architecture Guide](ARCHITECTURE.md) | 🔧 [Troubleshooting →](TROUBLESHOOTING.md)
