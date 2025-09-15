# 📊 DBeaver Connection Templates for CDC Pipeline

## 🔗 **Connection Profiles**

### **ClickHouse Connection**
```
Connection Name: CDC-ClickHouse-Analytics
Database Type: ClickHouse
Host: localhost
Port: 8123
Database: default
User: default
Password: (empty)
Additional Properties:
  - use_server_time_zone=true
  - socket_timeout=300000
```

### **PostgreSQL Connection**
```
Connection Name: CDC-PostgreSQL-Source
Database Type: PostgreSQL
Host: localhost
Port: 5432
Database: inventory
User: postgres
Password: postgres
Additional Properties:
  - ssl=false
  - ApplicationName=DBeaver-CDC-Monitor
```

## 📋 **Useful Monitoring Queries**

Save these queries in DBeaver for quick access:

### **1. CDC Pipeline Overview**
```sql
-- ClickHouse: Pipeline Health Dashboard
SELECT 
    'Pipeline Status' as metric,
    COUNT(DISTINCT table) as active_consumers,
    SUM(assignments.high_water_mark[1] - assignments.current_offset[1]) as total_lag,
    MAX(assignments.timestamp[1]) as last_activity
FROM system.kafka_consumers
ARRAY JOIN assignments;
```

### **2. Real-time Data Flow**
```sql
-- ClickHouse: Recent CDC Operations
SELECT 
    toStartOfMinute(_synced_at) as minute,
    operation,
    COUNT(*) as operations_count
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 10 MINUTE
GROUP BY minute, operation
ORDER BY minute DESC, operation;
```

### **3. Consumer Lag Monitoring**
```sql
-- ClickHouse: Kafka Consumer Lag
SELECT 
    table as kafka_table,
    assignments.topic[1] as topic,
    assignments.partition_id[1] as partition,
    assignments.current_offset[1] as current_offset,
    assignments.high_water_mark[1] as high_water_mark,
    assignments.high_water_mark[1] - assignments.current_offset[1] as lag,
    formatDateTime(assignments.timestamp[1], '%Y-%m-%d %H:%M:%S') as last_poll
FROM system.kafka_consumers
ARRAY JOIN assignments
ORDER BY lag DESC;
```

### **4. Data Quality Check**
```sql
-- ClickHouse: Data Completeness
SELECT 
    'orders' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT operation) as operation_types,
    MIN(_synced_at) as first_record,
    MAX(_synced_at) as latest_record,
    MAX(_synced_at) - MIN(_synced_at) as time_span
FROM orders_final;
```

### **5. Source Data Verification**
```sql
-- PostgreSQL: Source table counts
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows
FROM pg_stat_user_tables 
WHERE schemaname = 'inventory'
ORDER BY tablename;
```

### **6. Performance Analytics**
```sql
-- ClickHouse: Throughput Analysis
SELECT 
    toStartOfHour(_synced_at) as hour,
    COUNT(*) as messages_per_hour,
    COUNT(DISTINCT id) as unique_records,
    groupArray(operation) as operations
FROM orders_final 
WHERE _synced_at >= now() - INTERVAL 24 HOUR
GROUP BY hour
ORDER BY hour DESC;
```

## 🎯 **Quick Access Bookmarks**

Create these bookmarks in DBeaver:

1. **CDC Health Check** → Query #1 + #3
2. **Real-time Monitor** → Query #2 + #6  
3. **Data Validation** → Query #4 + #5
4. **Performance Dashboard** → All queries combined

## 🔧 **DBeaver Workspace Setup**

### **Folder Structure**
```
DBeaver Projects/
├── CDC-Pipeline/
│   ├── Connections/
│   │   ├── ClickHouse-Analytics
│   │   └── PostgreSQL-Source
│   ├── Scripts/
│   │   ├── monitoring-queries.sql
│   │   ├── health-check.sql
│   │   └── performance-analysis.sql
│   └── ER-Diagrams/
│       ├── source-schema.erd
│       └── target-schema.erd
```

### **Connection Tips**
- Enable **Auto-commit** for monitoring queries
- Set **Query timeout** to 60 seconds
- Use **Read-only** mode for production connections
- Create separate **Admin** connections for management

## 📈 **Advanced Monitoring**

### **Custom Dashboard Query**
```sql
-- ClickHouse: Complete CDC Dashboard
WITH pipeline_stats AS (
  SELECT 
    COUNT(*) as total_messages,
    COUNT(DISTINCT operation) as operation_types,
    MAX(_synced_at) as last_sync,
    now() - MAX(_synced_at) as seconds_behind
  FROM orders_final
),
consumer_stats AS (
  SELECT 
    COUNT(*) as active_consumers,
    SUM(assignments.high_water_mark[1] - assignments.current_offset[1]) as total_lag
  FROM system.kafka_consumers
  ARRAY JOIN assignments
)
SELECT 
  p.total_messages,
  p.operation_types,
  p.last_sync,
  p.seconds_behind,
  c.active_consumers,
  c.total_lag,
  CASE 
    WHEN c.total_lag = 0 AND p.seconds_behind < 60 THEN 'HEALTHY'
    WHEN c.total_lag < 100 AND p.seconds_behind < 300 THEN 'WARNING'
    ELSE 'CRITICAL'
  END as pipeline_status
FROM pipeline_stats p, consumer_stats c;
```

This query gives you a complete pipeline health overview in one result!