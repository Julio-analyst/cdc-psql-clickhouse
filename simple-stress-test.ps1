# SIMPLE STRESS TEST - 100K Records
Write-Host "🚀 Starting 100K Records Test" -ForegroundColor Cyan

$testStart = Get-Date
$batches = 100
$recordsPerBatch = 1000

Write-Host "Phase 1: Get Initial Counts"
$initialPG = docker exec postgres-source psql -h localhost -d inventory -U postgres -t -c "SELECT COUNT(*) FROM inventory.orders;"
$initialCH = docker exec clickhouse clickhouse-client --query "SELECT COUNT(*) FROM orders_final"
Write-Host "Initial - PostgreSQL: $($initialPG.Trim()), ClickHouse: $($initialCH.Trim())"

Write-Host "`nPhase 2: Bulk INSERT (100,000 records)"
$insertStart = Get-Date

for ($batch = 1; $batch -le $batches; $batch++) {
    # Generate CSV data
    $csvData = @()
    $startId = ($batch - 1) * $recordsPerBatch + 100000
    
    for ($i = 0; $i -lt $recordsPerBatch; $i++) {
        $orderDate = "2025-07-21"
        $purchaser = 1001 + ($i % 4)  # Cycle through 1001-1004
        $quantity = 1 + ($i % 10)     # 1-10
        $productId = 101 + ($i % 9)   # 101-109
        $csvData += "$orderDate,$purchaser,$quantity,$productId"
    }
    
    # Save and copy to PostgreSQL
    $tempFile = "batch_$batch.csv"
    $csvData | Out-File -FilePath $tempFile -Encoding ASCII
    docker cp $tempFile postgres-source:/tmp/
    docker exec postgres-source psql -h localhost -d inventory -U postgres -c "\COPY inventory.orders (order_date, purchaser, quantity, product_id) FROM '/tmp/$tempFile' DELIMITER ',' CSV;"
    docker exec postgres-source rm /tmp/$tempFile
    Remove-Item $tempFile -Force
    
    if ($batch % 20 -eq 0) {
        Write-Host "Batch $batch/$batches completed"
    }
}

$insertEnd = Get-Date
$insertDuration = ($insertEnd - $insertStart).TotalSeconds
$throughput = [math]::Round((100000 / $insertDuration), 2)
Write-Host "INSERT Complete: 100,000 records in $([math]::Round($insertDuration, 2))s ($throughput records/sec)"

Write-Host "`nWaiting 60 seconds for CDC sync..."
Start-Sleep -Seconds 60

$afterInsertPG = docker exec postgres-source psql -h localhost -d inventory -U postgres -t -c "SELECT COUNT(*) FROM inventory.orders;"
$afterInsertCH = docker exec clickhouse clickhouse-client --query "SELECT COUNT(*) FROM orders_final"
Write-Host "After INSERT - PostgreSQL: $($afterInsertPG.Trim()), ClickHouse: $($afterInsertCH.Trim())"

Write-Host "`nPhase 3: UPDATE Test (100 records)"
for ($i = 1; $i -le 100; $i++) {
    $targetId = 100000 + $i
    docker exec postgres-source psql -h localhost -d inventory -U postgres -c "UPDATE inventory.orders SET quantity = 50 WHERE id = $targetId;"
}
Write-Host "UPDATE Complete: 100 records updated"

Write-Host "`nPhase 4: DELETE Test (100 records)"
for ($i = 1; $i -le 100; $i++) {
    $targetId = 50000 + $i
    docker exec postgres-source psql -h localhost -d inventory -U postgres -c "DELETE FROM inventory.orders WHERE id = $targetId;"
}
Write-Host "DELETE Complete: 100 records deleted"

Write-Host "`nWaiting 60 seconds for final CDC sync..."
Start-Sleep -Seconds 60

$finalPG = docker exec postgres-source psql -h localhost -d inventory -U postgres -t -c "SELECT COUNT(*) FROM inventory.orders;"
$finalCH = docker exec clickhouse clickhouse-client --query "SELECT COUNT(*) FROM orders_final"

$testEnd = Get-Date
$totalTime = ($testEnd - $testStart).TotalMinutes

Write-Host "`n🎉 TEST COMPLETED!" -ForegroundColor Green
Write-Host "Total Time: $([math]::Round($totalTime, 2)) minutes" -ForegroundColor White
Write-Host "INSERT Throughput: $throughput records/second" -ForegroundColor White
Write-Host "Final PostgreSQL: $($finalPG.Trim())" -ForegroundColor White  
Write-Host "Final ClickHouse: $($finalCH.Trim())" -ForegroundColor White

Write-Host "`nCDC Operations Summary:"
docker exec clickhouse clickhouse-client --query "SELECT operation, count(*) FROM orders_final WHERE operation IN ('c','u','d') GROUP BY operation ORDER BY operation"
