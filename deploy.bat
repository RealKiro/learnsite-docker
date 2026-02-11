@echo off

set DB_NAME=learnsite
set CONTAINER_DB=learnsite2025-9-19-db-1
set CONTAINER_WEB=learnsite2025-9-19-web-1
set SQLCMD=/opt/mssql-tools18/bin/sqlcmd
set DBPWD=LearnSite!2025StrongPwd

set RESET=0
if /i "%~1"=="reset" set RESET=1
if /i "%~1"=="-reset" set RESET=1
if /i "%~1"=="--reset" set RESET=1

echo ========================================
echo     LearnSite One-Click Deploy
echo ========================================
echo.

echo [1/5] Starting Docker containers...
if %RESET%==1 (
    echo       Reset mode: removing containers...
    docker-compose down -v >nul 2>&1
)
docker-compose up -d >nul 2>&1
echo       Docker containers started!

echo [2/5] Waiting for SQL Server...
set attempt=0
set max_attempts=60

:wait_loop
set /a attempt+=1
docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -Q "SELECT 1" >nul 2>&1
if %errorlevel%==0 goto sql_ready
if %attempt% geq %max_attempts% (
    echo       SQL Server startup timeout!
    exit /b 1
)
echo       Waiting... (%attempt%/%max_attempts%)
timeout /t 2 /nobreak >nul
goto wait_loop

:sql_ready
echo       SQL Server is ready!

echo [3/5] Checking database...
docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -Q "SELECT name FROM sys.databases WHERE name = '%DB_NAME%'" 2>nul | findstr /i "%DB_NAME%" >nul
if %errorlevel%==0 (set DB_EXISTS=1) else (set DB_EXISTS=0)

if %DB_EXISTS%==1 if %RESET%==0 (
    echo       Database exists, skipping creation
    goto check_tables
)

echo       Creating database...
if %DB_EXISTS%==1 docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -Q "ALTER DATABASE %DB_NAME% SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE %DB_NAME%;" >nul 2>&1
docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -Q "CREATE DATABASE %DB_NAME%" >nul 2>&1
echo       Database created!

:check_tables

echo [4/5] Importing database script...
if %DB_EXISTS%==1 if %RESET%==0 (
    echo       Tables exist, skipping import
    goto verify
)
echo       Importing learnsite.sql...
docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -d %DB_NAME% -i /sql_scripts/learnsite.sql >nul 2>&1
echo       Import complete!

:verify

echo [5/5] Verifying deployment...
docker inspect -f "{{.State.Status}}" %CONTAINER_WEB% 2>nul | findstr "running" >nul
if %errorlevel%==0 (echo       Web service is running!) else (echo       Web service error!)

docker exec %CONTAINER_DB% %SQLCMD% -S localhost -U sa -P "%DBPWD%" -C -d %DB_NAME% -Q "SELECT 1" >nul 2>&1
if %errorlevel%==0 (echo       Database connection OK!) else (echo       Database connection failed!)

echo.
echo ========================================
echo     Deployment Complete!
echo ========================================
echo.
echo URL: http://localhost:8888
echo.
echo Commands:
echo   View logs:    docker-compose logs -f
echo   Stop:         docker-compose down
echo   Restart:      docker-compose restart
echo   Reset:        deploy.bat reset
echo.
