# ClickHouse Configuration

This folder contains essential ClickHouse server configuration files for the CDC pipeline.

## Configuration Files

### `config.xml`
- Main ClickHouse server configuration
- Sets up HTTP port (8123) and TCP port (9000)
- Configures logging and memory settings
- Enables access from all IPs for Docker networking
- **Simplified for single-node setup** (no ClickHouse Keeper dependency)

### `users.xml`
- User access and security configuration
- Defines default user with full access
- Sets memory limits and query logging
- Allows connections from any IP (suitable for containerized environment)

## Usage

These files are automatically mounted into the ClickHouse container:

```yaml
volumes:
  - ./clickhouse-config/config.xml:/etc/clickhouse-server/config.d/config.xml
  - ./clickhouse-config/users.xml:/etc/clickhouse-server/users.d/users.xml
```

## Access

- **HTTP Interface**: http://localhost:8123
- **TCP Interface**: localhost:9000  
- **MySQL Interface**: localhost:9004
- **Default User**: `default` (no password)

**Do not modify these files** unless you understand ClickHouse configuration requirements.