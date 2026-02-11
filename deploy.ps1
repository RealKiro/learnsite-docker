# LearnSite 一键部署脚本
# 使用方法: .\deploy.ps1
# 重置模式: .\deploy.ps1 -Reset

param(
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    LearnSite 一键部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$DB_PASSWORD = "LearnSite!2025StrongPwd"
$DB_NAME = "learnsite"
$CONTAINER_DB = "learnsite2025-9-19-db-1"
$CONTAINER_WEB = "learnsite2025-9-19-web-1"
$SQLCMD = "/opt/mssql-tools18/bin/sqlcmd"

function Run-Sql {
    param([string]$Query, [string]$Database = "master")
    $result = docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P $DB_PASSWORD -C -d $Database -Q $Query 2>&1
    return $result
}

function Wait-SqlServer {
    Write-Host "[2/5] 等待 SQL Server 启动..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        $attempt++
        try {
            $result = docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P $DB_PASSWORD -C -Q "SELECT 1" 2>&1
            if ($result -match "1") {
                Write-Host "      SQL Server 已就绪!" -ForegroundColor Green
                return $true
            }
        } catch {}
        Write-Host "      等待中... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
    Write-Host "      SQL Server 启动超时!" -ForegroundColor Red
    return $false
}

function Test-DatabaseExists {
    $result = Run-Sql "SELECT COUNT(*) FROM sys.databases WHERE name = '$DB_NAME'"
    return $result -match "^\s*1\s*$"
}

Write-Host "[1/5] 启动 Docker 容器..." -ForegroundColor Yellow
if ($Reset) {
    Write-Host "      重置模式: 停止并删除现有容器..." -ForegroundColor Magenta
    docker-compose down -v 2>&1 | Out-Null
}
docker-compose up -d 2>&1 | Where-Object { $_ -notmatch "level=warning" }
Write-Host "      Docker 容器已启动!" -ForegroundColor Green

if (-not (Wait-SqlServer)) {
    Write-Host "错误: SQL Server 启动失败" -ForegroundColor Red
    exit 1
}

Write-Host "[3/5] 检查数据库..." -ForegroundColor Yellow
$dbExists = Test-DatabaseExists
if ($dbExists -and -not $Reset) {
    Write-Host "      数据库 '$DB_NAME' 已存在，跳过创建" -ForegroundColor Green
} else {
    Write-Host "      正在创建数据库 '$DB_NAME'..." -ForegroundColor Yellow
    if ($dbExists) {
        Run-Sql "ALTER DATABASE $DB_NAME SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE $DB_NAME;" | Out-Null
    }
    Run-Sql "CREATE DATABASE $DB_NAME" | Out-Null
    Write-Host "      数据库创建成功!" -ForegroundColor Green
}

Write-Host "[4/5] 导入数据库脚本..." -ForegroundColor Yellow
$tableCheck = Run-Sql "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" $DB_NAME
$hasAllTables = $tableCheck -match "54"
if ($hasAllTables -and -not $Reset) {
    Write-Host "      数据表已完整 (54个表)，跳过导入" -ForegroundColor Green
} else {
    Write-Host "      正在导入 learnsite.sql ..." -ForegroundColor Yellow
    docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P $DB_PASSWORD -C -d $DB_NAME -i /sql_scripts/learnsite.sql 2>&1 | Out-Null
    $tableCount = Run-Sql "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" $DB_NAME
    if ($tableCount -match "(\d+)") {
        $count = $Matches[1]
        Write-Host "      导入完成! 共创建 $count 个数据表" -ForegroundColor Green
    }
}

Write-Host "[5/5] 验证部署..." -ForegroundColor Yellow
$webStatus = docker inspect -f '{{.State.Status}}' $CONTAINER_WEB 2>$null
if ($webStatus -eq "running") {
    Write-Host "      Web 服务运行正常!" -ForegroundColor Green
} else {
    Write-Host "      Web 服务状态: $webStatus" -ForegroundColor Red
}
$dbCheck = Run-Sql "SELECT 1" $DB_NAME
if ($dbCheck -match "1") {
    Write-Host "      数据库连接正常!" -ForegroundColor Green
} else {
    Write-Host "      数据库连接失败!" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    部署完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "访问地址: http://localhost:8888" -ForegroundColor White
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Gray
Write-Host "  查看日志:     docker-compose logs -f" -ForegroundColor Gray
Write-Host "  停止服务:     docker-compose down" -ForegroundColor Gray
Write-Host "  重启服务:     docker-compose restart" -ForegroundColor Gray
Write-Host "  重置部署:     .\deploy.ps1 -Reset" -ForegroundColor Gray
Write-Host ""
