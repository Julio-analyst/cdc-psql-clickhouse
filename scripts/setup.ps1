# CDC PostgreSQL to ClickHouse Setup Script
Write-Host "============================================" -ForegroundColor Green
Write-Host "  CDC PostgreSQL to ClickHouse Setup" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Function to check if container is healthy
function Wait-ForContainer {
    param($containerName, $maxWait = 60)
    
    Write-Host "Waiting for $containerName to be ready..." -ForegroundColor Yellow
    $waited = 0
    do {
        $status = docker ps --filter "name=$containerName" --format "{{.Status}}"
        if ($status -like "*healthy*" -or $status -like "*Up*") {
            Write-Host "$containerName is ready!" -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 2
        $waited += 2
    } while ($waited -lt $maxWait)
    
    Write-Host "$containerName failed to start within $maxWait seconds" -ForegroundColor Red
    return $false
}

# Step 1: Start all services
Write-Host ""
Write-Host "1. Starting all services..." -ForegroundColor Yellow
docker-compose up -d

# Step 2: Wait for services to be ready
Write-Host ""
Write-Host "2. Waiting for services to be ready..." -ForegroundColor Yellow
Wait-ForContainer "postgres-source" 30
Wait-ForContainer "kafka" 30
Wait-ForContainer "kafka-connect" 60
Wait-ForContainer "clickhouse" 30

# Step 3: Register Debezium source connector
Write-Host ""
Write-Host "3. Registering Debezium source connector..." -ForegroundColor Yellow

# Wait a bit longer for Kafka Connect to be fully ready
Write-Host "Waiting for Kafka Connect to be fully ready..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Check if Kafka Connect is responding
$maxRetries = 5
$retryCount = 0
$connectReady = $false

while ($retryCount -lt $maxRetries -and -not $connectReady) {
    try {
        $healthCheck = Invoke-RestMethod -Uri "http://localhost:8083/" -Method GET -TimeoutSec 10
        $connectReady = $true
        Write-Host "Kafka Connect is ready!" -ForegroundColor Green
    } catch {
        $retryCount++
        Write-Host "Waiting for Kafka Connect... (attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
}

if (-not $connectReady) {
    Write-Host "❌ Kafka Connect is not responding after $maxRetries attempts" -ForegroundColor Red
    exit 1
}

# Register Debezium connector
try {
    # First check if connector already exists
    try {
        $existingConnector = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector" -Method GET
        Write-Host "⚠️ Connector already exists, deleting first..." -ForegroundColor Yellow
        Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector" -Method DELETE
        Start-Sleep -Seconds 5
    } catch {
        # Connector doesn't exist, which is fine
    }
    
    $connectorConfig = Get-Content "config/debezium-source.json" -Raw
    $response = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method POST -ContentType "application/json" -Body $connectorConfig
    Write-Host "✅ Debezium connector registered successfully: $($response.name)" -ForegroundColor Green
    
    # Wait and verify connector is running
    Start-Sleep -Seconds 10
    $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector/status" -Method GET
    Write-Host "Connector state: $($status.connector.state)" -ForegroundColor $(if ($status.connector.state -eq "RUNNING") { "Green" } else { "Red" })
    
    if ($status.tasks) {
        Write-Host "Tasks:" -ForegroundColor Gray
        foreach ($task in $status.tasks) {
            Write-Host "  Task $($task.id): $($task.state)" -ForegroundColor $(if ($task.state -eq "RUNNING") { "Green" } else { "Red" })
        }
    }
    
} catch {
    Write-Host "❌ Failed to register Debezium connector: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
    exit 1
}

# Step 4: Wait for topics to be created
Write-Host ""
Write-Host "4. Waiting for Kafka topics to be created..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 5: Setup ClickHouse tables and materialized views
Write-Host ""
Write-Host "5. Setting up ClickHouse tables and materialized views..." -ForegroundColor Yellow
Get-Content "scripts/clickhouse-setup.sql" | docker exec -i clickhouse clickhouse-client --multiquery

# Step 6: Final verification
Write-Host ""
Write-Host "6. Final verification..." -ForegroundColor Yellow

# Check connector status again
try {
    $connectorStatus = Invoke-RestMethod -Uri "http://localhost:8083/connectors/postgres-source-connector/status" -Method GET
    Write-Host "Final connector state: $($connectorStatus.connector.state)" -ForegroundColor $(if ($connectorStatus.connector.state -eq "RUNNING") { "Green" } else { "Red" })
} catch {
    Write-Host "❌ Could not verify connector status" -ForegroundColor Red
}

# Wait a bit for topics to be fully created
Start-Sleep -Seconds 5

# Check Kafka topics
Write-Host "Checking Kafka topics..." -ForegroundColor Gray
try {
    $allTopics = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --list
    $debeziumTopics = $allTopics | Select-String "postgres-server"
    Write-Host "Debezium topics created: $($debeziumTopics.Count)" -ForegroundColor Green
    if ($debeziumTopics.Count -gt 0) {
        foreach ($topic in $debeziumTopics) {
            Write-Host "  ✓ $topic" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "Could not list Kafka topics" -ForegroundColor Red
}

# Check ClickHouse data
try {
    $ordersCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM orders_final"
    $customersCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM customers_final"
    $productsCount = docker exec -i clickhouse clickhouse-client --query "SELECT count(*) FROM products_final"
    
    Write-Host "ClickHouse data counts:" -ForegroundColor Green
    Write-Host "  Orders: $ordersCount" -ForegroundColor White
    Write-Host "  Customers: $customersCount" -ForegroundColor White
    Write-Host "  Products: $productsCount" -ForegroundColor White
} catch {
    Write-Host "Could not check ClickHouse data" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host " View orders: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM orders_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White
Write-Host " View customers: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM customers_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White
Write-Host " View products: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM products_final ORDER BY _synced_at DESC LIMIT 10`"" -ForegroundColor White
Write-Host " Monitor CDC: docker exec -i clickhouse clickhouse-client --query `"SELECT * FROM cdc_operations_summary FORMAT PrettyCompact`"" -ForegroundColor White
Write-Host " Kafdrop UI: http://localhost:9001" -ForegroundColor White
Write-Host " ClickHouse: http://localhost:8123" -ForegroundColor White

Write-Host ""
Write-Host "Test commands:" -ForegroundColor Cyan
Write-Host " Insert order: docker exec -i postgres-source psql -U postgres -d inventory -c `"INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) VALUES ('2025-07-18', 1001, 1, 102);`"" -ForegroundColor White
Write-Host " Insert customer: docker exec -i postgres-source psql -U postgres -d inventory -c `"INSERT INTO inventory.customers (first_name, last_name, email) VALUES ('John', 'Doe', 'john.doe@example.com');`"" -ForegroundColor White

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = Read-Host
