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