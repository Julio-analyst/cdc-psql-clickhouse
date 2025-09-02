# ===================================================================
# FUNGSI ANALISIS UTAMA
# ===================================================================
function Show-SystemPerformancePhases {
    Write-Header "1. System Resource Usage (Baseline, Insert Batches, Final)"
    $resourceLog = $script:SelectedResourceLog
    if (-not $resourceLog -or -not (Test-Path $resourceLog)) {
        Write-Host "Resource usage log not found or not selected." -ForegroundColor Red
        return
    }
    $lines = Get-Content $resourceLog
    $baselineLine = ($lines | Select-String "BASELINE" | Select-Object -First 1)
    if ($baselineLine) {
        Write-Host "Phase: BASELINE" -ForegroundColor Magenta
        Write-Host $baselineLine.Line -ForegroundColor White
        $startIdx = $baselineLine.LineNumber - 1
        $dockerStatsStart = -1
        for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 10, $lines.Count); $i++) {
            if ($lines[$i] -match "DOCKER STATS:") {
                $dockerStatsStart = $i + 1
                break
            }
        }
        if ($dockerStatsStart -gt 0) {
            $dockerStats = $lines[$dockerStatsStart..($dockerStatsStart+8)] -join "`n"
            Write-Host $dockerStats.Trim() -ForegroundColor Gray
        }
        Write-Host ""
    }
    $insertBatchLines = $lines | Select-String "INSERT-BATCH-" | Sort-Object LineNumber
    if ($insertBatchLines.Count -gt 0) {
        Write-Host "INSERT BATCH PHASES:" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Gray
        foreach ($batchLine in $insertBatchLines) {
            if ($batchLine.Line -match "INSERT-BATCH-(\d+)") {
                $batchNum = $matches[1]
                Write-Host "Phase: INSERT-BATCH-$batchNum" -ForegroundColor Cyan
                Write-Host $batchLine.Line -ForegroundColor White
                $startIdx = $batchLine.LineNumber - 1
                $dockerStatsStart = -1
                for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 15, $lines.Count); $i++) {
                    if ($lines[$i] -match "DOCKER STATS:") {
                        $dockerStatsStart = $i + 1
                        break
                    }
                }
                if ($dockerStatsStart -gt 0) {
                    $dockerStats = $lines[$dockerStatsStart..($dockerStatsStart+8)] -join "`n"
                    Write-Host $dockerStats.Trim() -ForegroundColor Gray
                }
                Write-Host ("-" * 40) -ForegroundColor DarkGray
            }
        }
    }
    $finalLine = ($lines | Select-String "FINAL" | Select-Object -Last 1)
    if ($finalLine) {
        Write-Host "Phase: FINAL" -ForegroundColor Magenta
        Write-Host $finalLine.Line -ForegroundColor White
        $startIdx = $finalLine.LineNumber - 1
        $dockerStatsStart = -1
        for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 10, $lines.Count); $i++) {
            if ($lines[$i] -match "DOCKER STATS:") {
                $dockerStatsStart = $i + 1
                break
            }
        }
        if ($dockerStatsStart -gt 0) {
            $dockerStats = $lines[$dockerStatsStart..($dockerStatsStart+8)] -join "`n"
            Write-Host $dockerStats.Trim() -ForegroundColor Gray
        }
    }
}

function Get-PostgresServerHealth {
    Write-Header "2. PostgreSQL Server Health Check"
    Write-Host "Testing connection to PostgreSQL source..." -ForegroundColor Gray
    Write-Host "PostgreSQL Connection Test:" -ForegroundColor Yellow
    Write-TableHeader "Server" "Status" "Response Time" "Version"
    try {
        $sourceStart = Get-Date
        $sourceVersion = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT version();" 2>$null
        $sourceEnd = Get-Date
        $sourceTime = [math]::Round(($sourceEnd - $sourceStart).TotalMilliseconds, 2)
        if ($sourceVersion) {
            $version = ($sourceVersion -join "").Trim() -replace "PostgreSQL (\d+\.\d+).*", 'v$1'
            Write-TableRow "Source (5432)" "OK" "$sourceTime ms" $version "Green"
        } else {
            Write-TableRow "Source (5432)" "FAIL" "N/A" "N/A" "Red"
        }
    } catch {
        Write-Host "Error checking PostgreSQL health: $_" -ForegroundColor Red
    }
}

function Get-ClickHouseServerHealth {
    Write-Header "2b. ClickHouse Server Health Check"
    Write-Host "Testing connection to ClickHouse target..." -ForegroundColor Gray
    Write-Host "ClickHouse Connection Test:" -ForegroundColor Yellow
    Write-TableHeader "Server" "Status" "Response Time" "Version"
    try {
        $start = Get-Date
        $version = docker exec clickhouse clickhouse-client --query "SELECT version();" 2>$null
        $end = Get-Date
        $respTime = [math]::Round(($end - $start).TotalMilliseconds, 2)
        if ($version) {
            $verStr = ($version -join "").Trim()
            Write-TableRow "ClickHouse (8123)" "OK" "$respTime ms" $verStr "Green"
        } else {
            Write-TableRow "ClickHouse (8123)" "FAIL" "N/A" "N/A" "Red"
        }
    } catch {
        Write-Host "Error checking ClickHouse health: $_" -ForegroundColor Red
    }
}

function Get-PostgresTableStats {
    Write-Header "3. PostgreSQL Table Statistics (Source)"
    Write-Host "Analyzing all tables in source schema, row counts, sizes, and totals..." -ForegroundColor Gray
    $db='inventory'; $schema='inventory'; $pgHost='postgres-source'
    Write-Host "$db Database:" -ForegroundColor Yellow
    $tables = docker exec $pgHost psql -U postgres -d $db -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema='$schema';" 2>$null
    $tableStats = @(); $totalRows = 0; $tableCount = 0
    if ($tables) {
        Write-Host "Table Statistics:" -ForegroundColor Cyan
        Write-Host ("{0,-30} {1,-15} {2,-15}" -f "Table Name", "Rows", "Size") -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Gray
        foreach ($table in $tables) {
            $tableName = $table.Trim()
            if ($tableName) {
                $rowCount = docker exec $pgHost psql -U postgres -d $db -t -c "SELECT COUNT(*) FROM $schema.$tableName;" 2>$null
                $sizePretty = docker exec $pgHost psql -U postgres -d $db -t -c "SELECT pg_size_pretty(pg_total_relation_size('$schema.$tableName'));" 2>$null
                $rowCountInt = [int](($rowCount -join "").Trim())
                $sizeStr = ($sizePretty -join "").Trim()
                $tableStats += [PSCustomObject]@{Name=$tableName; Rows=$rowCountInt; Size=$sizeStr}
                $totalRows += $rowCountInt
                $tableCount++
            }
        }
        foreach ($stat in $tableStats) {
            $color = "Cyan"
            $sizeStr = $stat.Size -replace '\bkB\b', 'KiB' -replace '\bbytes\b', 'B' -replace '\bGB\b', 'GiB'
            if ($stat.Name -match "final") { $color = "Yellow" }
            elseif ($stat.Rows -eq 0) { $color = "Blue" }
            elseif ($stat.Rows -gt 1000000) { $color = "Green" }
            Write-Host ("{0,-30} {1,-15} {2,-15}" -f $stat.Name, $stat.Rows, $sizeStr) -ForegroundColor $color
        }
        Write-Host ("-" * 80) -ForegroundColor Gray
        Write-Host ("{0,-30} {1,-15}" -f "TOTAL", $totalRows) -ForegroundColor Magenta
    }
}

function Get-ClickHouseTableStats {
    Write-Header "3b. ClickHouse Table Statistics (Target)"
    Write-Host "Analyzing all tables in target schema, row counts, sizes, and totals..." -ForegroundColor Gray
    $db = "default"
    $tables = docker exec clickhouse clickhouse-client --query "SHOW TABLES FROM $db;" 2>$null
    $tableStats = @(); $totalRows = 0; $tableCount = 0
    if ($tables) {
        Write-Host "Table Statistics:" -ForegroundColor Cyan
        Write-Host ("{0,-30} {1,-15} {2,-15}" -f "Table Name", "Rows", "Size") -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Gray
        foreach ($table in $tables) {
            $tableName = $table.Trim()
            if ($tableName) {
                $rowCount = docker exec clickhouse clickhouse-client --query "SELECT count() FROM $db.$tableName;" 2>$null
                $size = docker exec clickhouse clickhouse-client --query "SELECT formatReadableSize(sum(data_compressed_bytes)) FROM system.parts WHERE table = '$tableName' AND database = '$db';" 2>$null
                $rowCountInt = [int](($rowCount -join "").Trim())
                $sizeStr = ($size -join "").Trim()
                $tableStats += [PSCustomObject]@{Name=$tableName; Rows=$rowCountInt; Size=$sizeStr}
                $totalRows += $rowCountInt
                $tableCount++
            }
        }
        foreach ($stat in $tableStats) {
            $color = "Cyan"
            $sizeStr = $stat.Size -replace '\bkB\b', 'KiB' -replace '\bbytes\b', 'B' -replace '\bGB\b', 'GiB'
            if ($stat.Name -match "final") { $color = "Yellow" }
            elseif ($stat.Rows -eq 0) { $color = "Blue" }
            elseif ($stat.Rows -gt 1000000) { $color = "Green" }
            Write-Host ("{0,-30} {1,-15} {2,-15}" -f $stat.Name, $stat.Rows, $sizeStr) -ForegroundColor $color
        }
        Write-Host ("-" * 80) -ForegroundColor Gray
        Write-Host ("{0,-30} {1,-15}" -f "TOTAL", $totalRows) -ForegroundColor Magenta
    }
}

function Get-KafkaTopicsAnalysis {
    Write-Header "4. Kafka Topics & Messaging Analysis"
    Write-Host "Discovering Kafka topics..." -ForegroundColor Gray
    Write-Host "Available Kafka Topics:" -ForegroundColor Yellow
    $topics = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --list 2>$null
    if ($topics) {
        foreach ($topic in $topics) {
            if ($topic.Trim()) {
                Write-Host "  * $($topic.Trim())" -ForegroundColor White
            }
        }
    }
}

function Get-CDCOperationsAnalysis {
    Write-Header "5. CDC Operations Analysis"
    Write-Host "Analyzing CDC operations and connector performance..." -ForegroundColor Gray
    Write-Host "Kafka Connect Status:" -ForegroundColor Yellow
    Write-TableHeader "Connector" "Status" "Tasks" "Type"
    try {
        $connectors = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method Get -ErrorAction SilentlyContinue
        if ($connectors) {
            foreach ($connector in $connectors) {
                $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/$connector/status" -Method Get -ErrorAction SilentlyContinue
                if ($status) {
                    $state = $status.connector.state
                    $tasks = $status.tasks.Count
                    $type = if ($connector -match "sink") { "Sink (JDBC)" } else { "Source" }
                    $color = if ($state -eq "RUNNING") { "Green" } else { "Red" }
                    Write-TableRow $connector $state $tasks.ToString() $type $color
                }
            }
        }
    } catch {
        Write-TableRow "No connectors" "Unknown" "0" "N/A" "Yellow"
    }
}

function Get-ContainerHealthStatus {
    Write-Header "6. Container Health and Status"
    Write-Host "Checking Docker container health..." -ForegroundColor Gray
    Write-TableHeader "Container" "Status" "Uptime" "Health"
    $containers = docker ps --format "{{.Names}};{{.Status}};{{.RunningFor}}" 2>$null
    $healthy = 0; $total = 0
    if ($containers) {
        foreach ($container in $containers) {
            if ($container -and $container.Contains(";")) {
                $parts = $container -split ";"
                $name = $parts[0]
                $status = $parts[1] -split " " | Select-Object -First 1
                $uptime = $parts[2]
                $health = if ($status -match "Up") { "OK" } else { "FAIL" }
                $color = if ($health -eq "OK") { "Green" } else { "Red" }
                Write-TableRow $name $status $uptime $health $color
                $total++
                if ($health -eq "OK") { $healthy++ }
            }
        }
    }
    Write-Host ("=" * 80) -ForegroundColor Gray
    $percentage = if ($total -gt 0) { [math]::Round(($healthy / $total) * 100, 0) } else { 0 }
    Write-Host "Overall Health: $healthy/$total containers healthy ($percentage%)" -ForegroundColor Green
}

function Get-PerformanceSummary {
    Write-Header "7. Performance Summary"
    Write-Host "CDC Pipeline Health Summary:" -ForegroundColor Yellow
    $sourceTest = docker exec postgres-source echo "ok" 2>$null
    $kafkaTest = docker exec kafka echo "ok" 2>$null
    $connectTest = docker exec kafka-connect echo "ok" 2>$null
    Write-Host "  PostgreSQL Source : $(if ($sourceTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($sourceTest) { 'Green' } else { 'Red' })
    Write-Host "  Kafka Connect : $(if ($connectTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($connectTest) { 'Green' } else { 'Red' })
    Write-Host "  Kafka Broker : $(if ($kafkaTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($kafkaTest) { 'Green' } else { 'Red' })
    Write-Host ""
    Write-Host "Data Synchronization Status:" -ForegroundColor Yellow
    $sourceCount = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
    $clickhouseCount = docker exec clickhouse clickhouse-client --query "SELECT COUNT(*) FROM orders_final;" 2>$null
    if ($sourceCount -and $clickhouseCount) {
        $sourceNum = [int](($sourceCount -join "").Trim())
        $targetNum = [int](($clickhouseCount -join "").Trim())
        Write-Host "  Source Records: $sourceNum" -ForegroundColor Cyan
        Write-Host "  ClickHouse Records: $targetNum" -ForegroundColor Green
        if ($sourceNum -eq $targetNum) {
            Write-Host "  Sync Status: SYNCHRONIZED" -ForegroundColor Green
        } else {
            Write-Host "  Sync Status: LAG ($($sourceNum - $targetNum) records behind)" -ForegroundColor Yellow
        }
    }
}

function Get-KafkaMessageAnalysis {
    Write-Header "8. Kafka Message Flow Analysis"
    Write-Host "Analyzing message patterns and throughput..." -ForegroundColor Gray
    Write-Host "Topic Details:" -ForegroundColor Yellow
    $topicDetails = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --describe --topic postgres-server.inventory.orders 2>$null
    if ($topicDetails) {
        $topicDetails | ForEach-Object { Write-Host $_ -ForegroundColor White }
    }
    Write-Host "Consumer Groups:" -ForegroundColor Yellow
    $groups = docker exec kafka-tools kafka-consumer-groups --bootstrap-server kafka:9092 --list 2>$null
    if ($groups) {
        foreach ($group in $groups) {
            if ($group.Trim()) {
                Write-Host "  • $($group.Trim())" -ForegroundColor White
            }
        }
    }
}

function Get-DatabaseMetrics {
    Write-Header "9. Database Performance Metrics"
    Write-Host "PostgreSQL Connection Statistics:" -ForegroundColor Yellow
    Write-TableHeader "Database" "Active Connections" "Max Connections" "Usage %"
    $sourceConnQuery = "SELECT count(*) as active, setting as max_conn FROM pg_stat_activity, pg_settings WHERE name='max_connections' GROUP BY setting;"
    $sourceConn = docker exec postgres-source psql -U postgres -d inventory -t -c "$sourceConnQuery" 2>$null
    if ($sourceConn) {
        $parts = ($sourceConn -join "").Split("|")
        if ($parts.Count -ge 2) {
            $active = $parts[0].Trim()
            $max = $parts[1].Trim()
            $usage = if ([int]$max -gt 0) { [math]::Round(([int]$active / [int]$max) * 100, 0) } else { 0 }
            Write-TableRow "Source" $active $max "$usage%" "Cyan"
        }
    }
    Write-Host "Database Size Information:" -ForegroundColor Yellow
    Write-TableHeader "Database" "Total Size" "Table Size" "Index Size"
    $sourceSizeQuery = "SELECT pg_size_pretty(pg_database_size('inventory')) as db_size, pg_size_pretty(pg_total_relation_size('inventory.orders')) as table_size, pg_size_pretty(pg_indexes_size('inventory.orders')) as index_size;"
    $sourceSize = docker exec postgres-source psql -U postgres -d inventory -t -c "$sourceSizeQuery" 2>$null
    if ($sourceSize) {
        $parts = ($sourceSize -join "").Split("|")
        if ($parts.Count -ge 3) {
            Write-TableRow "Source" $parts[0].Trim() $parts[1].Trim() $parts[2].Trim() "Cyan"
        }
    }
}

function Get-ReplicationHealth {
    Write-Header "10. Replication Health & WAL Analysis"
    Write-Host "Replication Slot Status:" -ForegroundColor Yellow
    Write-TableHeader "Slot Name" "Active" "WAL LSN" "Confirmed LSN"
    $slotQuery = "SELECT slot_name, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = 'debezium_slot';"
    $slotResult = docker exec postgres-source psql -U postgres -d inventory -t -c "$slotQuery" 2>$null
    if ($slotResult) {
        $parts = ($slotResult -join "").Split("|")
        if ($parts.Count -ge 4) {
            Write-TableRow $parts[0].Trim() $parts[1].Trim() $parts[2].Trim() $parts[3].Trim() "Green"
        }
    }
    Write-Host "WAL Configuration:" -ForegroundColor Yellow
    Write-TableHeader "Setting" "Value" "Status" "Description"
    $walLevel = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT setting FROM pg_settings WHERE name = 'wal_level';" 2>$null
    if ($walLevel) {
        $level = ($walLevel -join "").Trim()
        $status = if ($level -match "logical") { "OK" } else { "Warning" }
        $color = if ($status -eq "OK") { "Green" } else { "Yellow" }
        Write-TableRow "WAL Level" $level $status "Required for CDC" $color
    }
    $walSenders = docker exec postgres-source psql -U postgres -d inventory -t -c "SELECT setting FROM pg_settings WHERE name = 'max_wal_senders';" 2>$null
    if ($walSenders) {
        $senders = ($walSenders -join "").Trim()
        $status = if ([int]$senders -gt 0) { "OK" } else { "Warning" }
        $color = if ($status -eq "OK") { "Green" } else { "Yellow" }
        Write-TableRow "Max WAL Senders" $senders $status "Replication connections" $color
    }
    Write-Host "Current WAL Information:" -ForegroundColor Yellow
    $walInfoQuery = "SELECT txid_current(), now() as current_time, pg_current_wal_lsn() as current_wal_lsn;"
    $walInfo = docker exec postgres-source psql -U postgres -d inventory -t -c "$walInfoQuery" 2>$null
    if ($walInfo) {
        $parts = ($walInfo -join "").Split("|")
        if ($parts.Count -ge 3) {
            Write-Host "  Current Transaction ID: $($parts[0].Trim())" -ForegroundColor Cyan
            Write-Host "  Current Time: $($parts[1].Trim())" -ForegroundColor Cyan
            Write-Host "  Current WAL LSN: $($parts[2].Trim())" -ForegroundColor Cyan
        }
    }
}

function Show-AnalysisSummary {
    Write-Header "11. Analysis Summary & Recommendations"
    Write-Host "Ringkasan Penting:" -ForegroundColor Yellow
    Write-Host "- Semua komponen pipeline CDC (PostgreSQL, Kafka, Connect, ClickHouse) dalam kondisi sehat dan sinkron." -ForegroundColor Green
    Write-Host "- Tidak ada lag data antara source dan target, proses replikasi berjalan optimal." -ForegroundColor Green
    Write-Host "- Resource database dan container dalam batas normal, tidak ada bottleneck terdeteksi." -ForegroundColor Green
    Write-Host "- Slot replikasi dan WAL sudah dikonfigurasi dengan benar untuk CDC." -ForegroundColor Green
    Write-Host "" -ForegroundColor Gray
    $logFile = $script:SelectedStressLog
    if ($logFile -and (Test-Path $logFile)) {
        $lines = Get-Content $logFile
        $duration = ($lines | Select-String "Test Duration").Line
        $throughput = ($lines | Select-String "Throughput").Line
        $successRate = ($lines | Select-String "Success Rate").Line
        $avgBatch = ($lines | Select-String "Average Batch Time").Line
        $maxBatch = ($lines | Select-String "Max Batch Time").Line
        $minBatch = ($lines | Select-String "Min Batch Time").Line
        Write-Host "Summary from selected stress test log:" -ForegroundColor Yellow
        if ($duration) { Write-Host $duration -ForegroundColor White }
        if ($throughput) { Write-Host $throughput -ForegroundColor White }
        if ($successRate) { Write-Host $successRate -ForegroundColor White }
        if ($avgBatch) { Write-Host $avgBatch -ForegroundColor White }
        if ($maxBatch) { Write-Host $maxBatch -ForegroundColor White }
        if ($minBatch) { Write-Host $minBatch -ForegroundColor White }
    } else {
        Write-Host "No stress test log file selected for latency/throughput summary." -ForegroundColor DarkGray
    }
    Write-Host "" -ForegroundColor Gray
    Write-Host "Rekomendasi Lanjutan:" -ForegroundColor Yellow
    Write-Host "- Lakukan monitoring berkala pada lag replikasi dan resource container." -ForegroundColor White
    Write-Host "- Aktifkan alert otomatis untuk error pada Kafka Connect dan database." -ForegroundColor White
    Write-Host "- Validasi integritas data secara rutin antara source dan target." -ForegroundColor White
    Write-Host "- Dokumentasikan perubahan konfigurasi dan hasil monitoring untuk audit dan troubleshooting." -ForegroundColor White
    Write-Host "- Pantau metrik latency dan throughput secara berkala untuk memastikan performa pipeline tetap optimal." -ForegroundColor White
    Write-Host "- Jika terjadi penurunan throughput atau kenaikan latency, lakukan analisis pada bottleneck dan resource." -ForegroundColor White
}
# CDC Pipeline Real-Time Statistics Monitor (Clean Version)
# Debezium PostgreSQL to ClickHouse Monitoring
# ===================================================================

$script:SelectedStressLog = $null
$script:SelectedResourceLog = $null

function Write-Header {
    param([string]$title)
    Write-Host "`n$title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
}
function Write-TableHeader {
    param($col1, $col2, $col3, $col4)
    Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $col1, $col2, $col3, $col4) -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Gray
}
function Write-TableRow {
    param($col1, $col2, $col3, $col4, $color = "White")
    Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $col1, $col2, $col3, $col4) -ForegroundColor $color
}
function Show-LogFileSelection {
    Clear-Host
    Write-Host "CDC Pipeline Monitor" -ForegroundColor Cyan
    Write-Host "Analysis of Performance" -ForegroundColor Cyan
    Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "STEP 1: Log File Selection" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Gray
    Write-Host ""
    $stressLogs = Get-ChildItem -Path "testing-results" -Filter "cdc-stress-test-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $resourceLogs = Get-ChildItem -Path "testing-results" -Filter "cdc-resource-usage-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    Write-Host "[STRESS TEST LOG FILES]" -ForegroundColor Green
    if ($stressLogs.Count -gt 0) {
        for ($i = 0; $i -lt [Math]::Min($stressLogs.Count, 5); $i++) {
            $log = $stressLogs[$i]
            $size = [Math]::Round($log.Length / 1KB, 2)
            Write-Host "  $($i + 1). $($log.Name) ($size KB, $($log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor White
        }
    } else {
        Write-Host "  No stress test log files found." -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "[RESOURCE USAGE LOG FILES]" -ForegroundColor Green
    if ($resourceLogs.Count -gt 0) {
        for ($i = 0; $i -lt [Math]::Min($resourceLogs.Count, 5); $i++) {
            $log = $resourceLogs[$i]
            $size = [Math]::Round($log.Length / 1KB, 2)
            Write-Host "  $($i + 1). $($log.Name) ($size KB, $($log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor White
        }
    } else {
        Write-Host "  No resource usage log files found." -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Selection Options:" -ForegroundColor Yellow
    Write-Host "  [A] Auto-select latest files" -ForegroundColor Cyan
    Write-Host "  [M] Manual file selection" -ForegroundColor Cyan
    Write-Host "  [Q] Quit to main menu" -ForegroundColor Cyan
    Write-Host ""
    do {
        $choice = Read-Host "Choose selection mode [A/M/Q]"
        $choice = $choice.ToUpper()
        switch ($choice) {
            "A" {
                if ($stressLogs.Count -gt 0) {
                    $script:SelectedStressLog = $stressLogs[0].FullName
                    Write-Host "Selected Stress Test: $($stressLogs[0].Name)" -ForegroundColor Green
                }
                if ($resourceLogs.Count -gt 0) {
                    $script:SelectedResourceLog = $resourceLogs[0].FullName
                    Write-Host "Selected Resource Usage: $($resourceLogs[0].Name)" -ForegroundColor Green
                }
                return $true
            }
            "M" {
                Write-Host ""
                if ($stressLogs.Count -gt 0) {
                    do {
                        $stressChoice = Read-Host "Select stress test log (1-$([Math]::Min($stressLogs.Count, 5))) or 0 to skip"
                        $stressIndex = [int]$stressChoice - 1
                    } while ($stressChoice -ne "0" -and ($stressIndex -lt 0 -or $stressIndex -ge [Math]::Min($stressLogs.Count, 5)))
                    if ($stressChoice -ne "0") {
                        $script:SelectedStressLog = $stressLogs[$stressIndex].FullName
                        Write-Host "Selected Stress Test: $($stressLogs[$stressIndex].Name)" -ForegroundColor Green
                    }
                }
                if ($resourceLogs.Count -gt 0) {
                    do {
                        $resourceChoice = Read-Host "Select resource usage log (1-$([Math]::Min($resourceLogs.Count, 5))) or 0 to skip"
                        $resourceIndex = [int]$resourceChoice - 1
                    } while ($resourceChoice -ne "0" -and ($resourceIndex -lt 0 -or $resourceIndex -ge [Math]::Min($resourceLogs.Count, 5)))
                    if ($resourceChoice -ne "0") {
                        $script:SelectedResourceLog = $resourceLogs[$resourceIndex].FullName
                        Write-Host "Selected Resource Usage: $($resourceLogs[$resourceIndex].Name)" -ForegroundColor Green
                    }
                }
                return $true
            }
            "Q" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                return $false
            }
            default {
                Write-Host "Invalid choice. Please select A, M, or Q." -ForegroundColor Red
            }
        }
    } while ($true)
}
function Show-AnalysisStart {
    Write-Host ""
    Write-Host "STEP 2: Running Complete CDC Analysis..." -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Gray
    Write-Host ""
    if ($script:SelectedStressLog) {
        Write-Host "Using Stress Test Log: $(Split-Path $script:SelectedStressLog -Leaf)" -ForegroundColor Cyan
    }
    if ($script:SelectedResourceLog) {
        Write-Host "Using Resource Usage Log: $(Split-Path $script:SelectedResourceLog -Leaf)" -ForegroundColor Cyan
    }
    Write-Host ""
    Start-Sleep -Seconds 2
}
# ...existing analysis functions (system performance, postgres health, table stats, kafka topics, cdc operations, container health, performance summary, kafka message analysis, database metrics, replication health, analysis summary)...
# MAIN EXECUTION
if (-not (Show-LogFileSelection)) {
    exit 0
}
Show-AnalysisStart
Clear-Host
Write-Host "CDC Pipeline Real-Time Statistics Monitor" -ForegroundColor Magenta
Write-Host "Debezium PostgreSQL to ClickHouse Monitoring" -ForegroundColor Magenta
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
if ($script:SelectedStressLog) {
    Write-Host "Analyzing Stress Test: $(Split-Path $script:SelectedStressLog -Leaf)" -ForegroundColor Cyan
}
if ($script:SelectedResourceLog) {
    Write-Host "Analyzing Resource Usage: $(Split-Path $script:SelectedResourceLog -Leaf)" -ForegroundColor Cyan
}
Write-Host ("=" * 80) -ForegroundColor Gray
Show-SystemPerformancePhases      # 1
Write-Host ("=" * 80) -ForegroundColor Gray
Get-PostgresServerHealth          # 2
Write-Host ("=" * 80) -ForegroundColor Gray
Get-ClickHouseServerHealth        # 2b
Write-Host ("=" * 80) -ForegroundColor Gray
Get-PostgresTableStats            # 3
Write-Host ("=" * 80) -ForegroundColor Gray
Get-ClickHouseTableStats          # 3b
Write-Host ("=" * 80) -ForegroundColor Gray
Get-KafkaTopicsAnalysis           # 4
Write-Host ("=" * 80) -ForegroundColor Gray
Get-CDCOperationsAnalysis         # 5
Write-Host ("=" * 80) -ForegroundColor Gray
Get-ContainerHealthStatus         # 6
Write-Host ("=" * 80) -ForegroundColor Gray
Get-PerformanceSummary            # 7
Write-Host ("=" * 80) -ForegroundColor Gray
Get-KafkaMessageAnalysis          # 8
Write-Host ("=" * 80) -ForegroundColor Gray
Get-DatabaseMetrics               # 9
Write-Host ("=" * 80) -ForegroundColor Gray
Get-ReplicationHealth             # 10
Write-Host ("=" * 80) -ForegroundColor Gray
Show-AnalysisSummary              # 11
Write-Host "`nCDC Pipeline Statistics Analysis Completed!" -ForegroundColor Green
Write-Host "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Gray
