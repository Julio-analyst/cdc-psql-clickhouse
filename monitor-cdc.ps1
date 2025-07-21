# 📊 CDC Operations Monitor
# Quick script to view CDC pipeline statistics

Write-Host "CDC OPERATIONS SUMMARY" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

Write-Host "`nCurrent CDC Statistics:" -ForegroundColor Yellow
docker exec clickhouse clickhouse-client --query "SELECT * FROM cdc_operations_summary FORMAT PrettyCompact"

Write-Host "`nOperation Types Legend:" -ForegroundColor Gray
Write-Host "  r = Read/Snapshot (initial data load)" -ForegroundColor White
Write-Host "  c = Create/Insert" -ForegroundColor White  
Write-Host "  u = Update" -ForegroundColor White
Write-Host "  d = Delete" -ForegroundColor White

Write-Host "`nDetailed View:" -ForegroundColor Yellow
Write-Host "Orders table:" -ForegroundColor Cyan
docker exec clickhouse clickhouse-client --query "SELECT operation, count(*) FROM orders_final GROUP BY operation ORDER BY operation FORMAT PrettyCompact"

Write-Host "`nCustomers table:" -ForegroundColor Cyan
docker exec clickhouse clickhouse-client --query "SELECT operation, count(*) FROM customers_final GROUP BY operation ORDER BY operation FORMAT PrettyCompact"

Write-Host "`nProducts table:" -ForegroundColor Cyan
docker exec clickhouse clickhouse-client --query "SELECT operation, count(*) FROM products_final GROUP BY operation ORDER BY operation FORMAT PrettyCompact"

Write-Host "`nLast sync times:" -ForegroundColor Yellow
docker exec clickhouse clickhouse-client --query "SELECT table_name, max(_synced_at) as last_sync FROM (SELECT 'orders' as table_name, _synced_at FROM orders_final UNION ALL SELECT 'customers', _synced_at FROM customers_final UNION ALL SELECT 'products', _synced_at FROM products_final) GROUP BY table_name ORDER BY table_name FORMAT PrettyCompact"

Write-Host "`nCDC Pipeline Status: Active" -ForegroundColor Green
Write-Host "Monitor this view in real-time to track CDC operations!" -ForegroundColor Gray
