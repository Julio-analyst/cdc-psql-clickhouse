# CDC PostgreSQL to ClickHouse Setup Script
# This script automates the complete setup of CDC pipeline from PostgreSQL to ClickHouse
# Author: Julio-analyst | Purpose: Production-ready CDC setup with error handling

# Display header for better user experience
Write-Host "============================================" -ForegroundColor Green
Write-Host "  CDC PostgreSQL to ClickHouse Setup" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Function to wait for Docker containers to be healthy/ready
# CUSTOMIZE: Modify maxWait values if your containers take longer to start
function Wait-ForContainer {
    param(
        $containerName,     # Name of the container to check (must match docker-compose.yml service names)
        $maxWait = 60      # Maximum seconds to wait (CUSTOMIZE: increase for slower systems)
    )
    
    Write-Host "Waiting for $containerName to be ready..." -ForegroundColor Yellow
    $waited = 0
    do {
        # Get container status using Docker CLI
        # CUSTOMIZE: Add more status checks if needed (e.g., specific health endpoints)
        $status = docker ps --filter "name=$containerName" --format "{{.Status}}"
        
        # Check if container is healthy or running
        # CUSTOMIZE: Modify conditions based on your container health check setup
            if ($status -like "*healthy*") {
                Write-Host "$containerName is healthy!" -ForegroundColor Green
                return $true
            } elseif ($status -like "*Up*") {
                Write-Host "$containerName status: Up (belum healthy)" -ForegroundColor Yellow
            }
        
        # Wait 2 seconds before next check (CUSTOMIZE: adjust polling interval)
        Start-Sleep -Seconds 2
        $waited += 2
    } while ($waited -lt $maxWait)
    
    # Container failed to start within timeout
    Write-Host "$containerName failed to start within $maxWait seconds" -ForegroundColor Red
    return $false
}

# STEP 1: START ALL DOCKER SERVICES
# This starts all services defined in docker-compose.yml in detached mode
Write-Host ""
Write-Host "1. Starting all services..." -ForegroundColor Yellow
# CUSTOMIZE: Replace 'docker-compose.yml' with your custom compose file if different
docker-compose up -d

# STEP 2: WAIT FOR CORE SERVICES TO BE READY
# Critical services must be running before proceeding to connector setup
Write-Host ""
Write-Host "2. Waiting for services to be ready..." -ForegroundColor Yellow

# Wait for PostgreSQL source database (contains your business data)
# CUSTOMIZE: Change container name if you modify docker-compose.yml service name
Wait-ForContainer "postgres-source" 30

# Wait for Kafka message broker (handles CDC events)
# CUSTOMIZE: Increase timeout if Kafka takes longer to start on your system
Wait-ForContainer "kafka" 30

# Wait for Kafka Connect (runs Debezium connector)
# CUSTOMIZE: This often takes longest - increase timeout for production systems
Wait-ForContainer "kafka-connect" 60

# Wait for ClickHouse analytics database (destination for CDC data)
# CUSTOMIZE: Adjust timeout based on your ClickHouse configuration
Wait-ForContainer "clickhouse" 30

# STEP 3: REGISTER DEBEZIUM SOURCE CONNECTOR
# This sets up the CDC connector that captures changes from PostgreSQL
Write-Host ""
Write-Host "3. Registering Debezium source connector..." -ForegroundColor Yellow

# Extra wait for Kafka Connect to fully initialize its REST API
# CUSTOMIZE: Increase if you have many plugins or slower system
Write-Host "Waiting for Kafka Connect to be fully ready..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Retry logic for Kafka Connect REST API readiness
# CUSTOMIZE: Modify retry count and timeout based on your environment
$maxRetries = 5                # Maximum connection attempts
$retryCount = 0               # Current attempt counter
$connectReady = $false        # Connection status flag

while ($retryCount -lt $maxRetries -and -not $connectReady) {
    try {
        # Test Kafka Connect REST API endpoint
        # CUSTOMIZE: Change port if you modify Kafka Connect port in docker-compose.yml
        $healthCheck = Invoke-RestMethod -Uri "http://localhost:8083/" -Method GET -TimeoutSec 10
        $connectReady = $true
        Write-Host "Kafka Connect is ready!" -ForegroundColor Green
    } catch {
        $retryCount++
        Write-Host "Waiting for Kafka Connect... (attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
        # CUSTOMIZE: Adjust wait time between retries
        Start-Sleep -Seconds 10
    }
}

# Exit if Kafka Connect is not responding
if (-not $connectReady) {
    Write-Host "❌ Kafka Connect is not responding after $maxRetries attempts" -ForegroundColor Red
    # CUSTOMIZE: Add additional debugging commands here if needed
    exit 1
}

# REGISTER THE DEBEZIUM CONNECTOR CONFIGURATION
try {
    # Check if connector already exists and remove it for clean setup
    # CUSTOMIZE: Change connector name if you modify it in debezium-source.json
    try {
        $existingConnector = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector" -Method GET
        Write-Host "⚠️ Connector already exists, deleting first..." -ForegroundColor Yellow
        # Delete existing connector to avoid conflicts
        Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector" -Method DELETE
        Start-Sleep -Seconds 5  # Wait for cleanup to complete
    } catch {
        # Connector doesn't exist, which is normal for first-time setup
    }
    
    # Load connector configuration from JSON file
    # CUSTOMIZE: Modify path if you move the config file or create custom configs
    $connectorConfig = Get-Content "config/debezium-source.json" -Raw
    
    # POST the connector configuration to Kafka Connect
    # CUSTOMIZE: Modify URL/port if you change Kafka Connect configuration
    $response = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method POST -ContentType "application/json" -Body $connectorConfig
    Write-Host "✅ Debezium connector registered successfully: $($response.name)" -ForegroundColor Green
    
    # Wait for connector to initialize and start tasks
    # CUSTOMIZE: Increase wait time for databases with many tables
    Start-Sleep -Seconds 10
    
    # Verify connector is running properly
    # CUSTOMIZE: Add additional status checks if needed
    $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector/status" -Method GET
    Write-Host "Connector state: $($status.connector.state)" -ForegroundColor $(if ($status.connector.state -eq "RUNNING") { "Green" } else { "Red" })
    
    # Check individual task status (Debezium creates tasks per table/partition)
    if ($status.tasks) {
        Write-Host "Tasks:" -ForegroundColor Gray
        foreach ($task in $status.tasks) {
            # Each task should be RUNNING for full CDC functionality
            Write-Host "  Task $($task.id): $($task.state)" -ForegroundColor $(if ($task.state -eq "RUNNING") { "Green" } else { "Red" })
        }
    }
    
} catch {
    # Handle connector registration failures
    Write-Host "❌ Failed to register Debezium connector: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
    # CUSTOMIZE: Add specific error handling or debugging steps here
    exit 1
}

# STEP 4: WAIT FOR KAFKA TOPICS CREATION
# Debezium automatically creates topics for each table it monitors
Write-Host ""
Write-Host "4. Waiting for Kafka topics to be created..." -ForegroundColor Yellow
# CUSTOMIZE: Increase wait time if you have many tables or slow topic creation
Start-Sleep -Seconds 10

# STEP 5: SETUP CLICKHOUSE DESTINATION TABLES
# Create tables and materialized views that will receive CDC data
Write-Host ""
Write-Host "5. Setting up ClickHouse tables and materialized views..." -ForegroundColor Yellow
# CUSTOMIZE: Modify clickhouse-setup.sql file to match your schema requirements
# CUSTOMIZE: Change file path if you move the SQL setup file
Get-Content "scripts/clickhouse-setup.sql" | docker exec -i clickhouse clickhouse-client --multiquery

# STEP 6: FINAL VERIFICATION AND STATUS CHECKS
# Comprehensive verification that everything is working correctly
Write-Host ""
Write-Host "6. Final verification..." -ForegroundColor Yellow

# Re-check connector status to ensure it's still running
try {
    # CUSTOMIZE: Change connector name if modified in configuration
    $connectorStatus = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector/status" -Method GET
    Write-Host "Final connector state: $($connectorStatus.connector.state)" -ForegroundColor $(if ($connectorStatus.connector.state -eq "RUNNING") { "Green" } else { "Red" })
} catch {
    Write-Host "❌ Could not verify connector status" -ForegroundColor Red
    # CUSTOMIZE: Add debugging steps here if connector verification fails
}

# Wait for topics to be fully created and accessible
# CUSTOMIZE: Adjust wait time based on your system performance
Start-Sleep -Seconds 5

# LIST AND VERIFY KAFKA TOPICS
Write-Host "Checking Kafka topics..." -ForegroundColor Gray
try {
    # Get all topics from Kafka cluster
    # CUSTOMIZE: Change container names if modified in docker-compose.yml
    $allTopics = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --list
    
    # Filter for Debezium-created topics (server name from connector config)
    # CUSTOMIZE: Change "postgres-server" if you modify server.name in debezium-source.json
    $debeziumTopics = $allTopics | Select-String "postgres-server"
    Write-Host "Debezium topics created: $($debeziumTopics.Count)" -ForegroundColor Green
    
    # List each topic for verification
    if ($debeziumTopics.Count -gt 0) {
        foreach ($topic in $debeziumTopics) {
            Write-Host "  ✓ $topic" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "Could not list Kafka topics" -ForegroundColor Red
    # CUSTOMIZE: Add additional Kafka debugging if needed
}

# VERIFY CLICKHOUSE DATA SYNCHRONIZATION
# Check that CDC data is flowing into ClickHouse destination tables
try {
    # Query final tables to verify data synchronization
    # CUSTOMIZE: Add/remove table checks based on your schema
    # CUSTOMIZE: Change table names if you modify them in clickhouse-setup.sql
    $ordersCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM orders_final"
    $customersCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM customers_final"
    $productsCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM products_final"
    
    # Display data counts for verification
    Write-Host "ClickHouse data counts:" -ForegroundColor Green
    Write-Host "  Orders: $ordersCount" -ForegroundColor White
    Write-Host "  Customers: $customersCount" -ForegroundColor White
    Write-Host "  Products: $productsCount" -ForegroundColor White
    
    # CUSTOMIZE: Add validation logic here (e.g., minimum expected counts)
    
} catch {
    Write-Host "Could not check ClickHouse data" -ForegroundColor Red
    # CUSTOMIZE: Add ClickHouse debugging steps here
}

# SETUP COMPLETION BANNER
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# USEFUL COMMANDS AND ENDPOINTS FOR POST-SETUP USAGE
# These commands help users interact with and monitor the CDC system
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan

# ClickHouse query examples for verifying data sync
# CUSTOMIZE: Modify these queries to match your table schema and business logic
Write-Host " View orders: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM orders_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White
Write-Host " View customers: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM customers_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White
Write-Host " View products: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM products_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White

# CDC monitoring and operations summary query
# CUSTOMIZE: Modify if you change the summary table name in clickhouse-setup.sql
Write-Host " Monitor CDC: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM cdc_operations_summary FORMAT PrettyCompact`"" -ForegroundColor White

# Web interface URLs for monitoring and management
# CUSTOMIZE: Change ports if you modify them in docker-compose.yml
Write-Host " Kafdrop UI: http://localhost:9001" -ForegroundColor White       # Kafka topic browser and message viewer
Write-Host " ClickHouse: http://localhost:8123" -ForegroundColor White       # ClickHouse web interface and query runner

Write-Host ""
Write-Host "Test commands:" -ForegroundColor Cyan

# Sample INSERT commands to test CDC functionality
# CUSTOMIZE: Modify these to match your business data and table schemas
# These commands insert data into PostgreSQL and should appear in ClickHouse within seconds
Write-Host " Insert order: docker exec -i postgres-source psql -U postgres -d inventory -c `"INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) VALUES ('2025-07-18', 1001, 1, 102);`"" -ForegroundColor White
Write-Host " Insert customer: docker exec -i postgres-source psql -U postgres -d inventory -c `"INSERT INTO inventory.customers (first_name, last_name, email) VALUES ('John', 'Doe', 'john.doe@example.com');`"" -ForegroundColor White

# CUSTOMIZE: Add UPDATE and DELETE examples if needed for your testing
# CUSTOMIZE: Add custom business logic testing commands

Write-Host ""
# Wait for user input before closing (useful for batch/automated runs)
# CUSTOMIZE: Remove this if you want the script to complete without user interaction
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = Read-Host
