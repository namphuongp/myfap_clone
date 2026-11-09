$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$runtimeRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.local\mysql-runtime'))
$mysqlBase = Join-Path $runtimeRoot 'mysql-8.0.46-winx64'
$mysqlExe = Join-Path $mysqlBase 'bin\mysqld.exe'

function Test-LocalPort([int]$Port) {
    $client = [Net.Sockets.TcpClient]::new()
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $client.Dispose() }
}

if (!(Test-Path -LiteralPath $mysqlExe)) {
    throw 'Không tìm thấy MySQL portable trong thư mục .local của dự án. Dùng hướng dẫn Docker/MySQL trong README.md.'
}
if (!(Test-LocalPort 13379)) {
    $mysqlArguments = @('--no-defaults', ('--basedir="{0}"' -f $mysqlBase), ('--datadir="{0}"' -f (Join-Path $runtimeRoot 'data')), '--bind-address=127.0.0.1', '--port=13379', '--mysqlx=0', '--console')
    Start-Process -FilePath $mysqlExe -ArgumentList $mysqlArguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runtimeRoot 'server.stdout.log') -RedirectStandardError (Join-Path $runtimeRoot 'server.stderr.log') | Out-Null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if (Test-LocalPort 13379) { break }
        Start-Sleep -Seconds 1
    }
    if (!(Test-LocalPort 13379)) { throw 'MySQL chưa khởi động được. Xem .local/mysql-runtime/server.stderr.log.' }
}

if (!(Test-LocalPort 3000)) {
    $backendRoot = Join-Path $projectRoot 'backend'
    Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList @('--env-file=.env', 'src/server.js') -WorkingDirectory $backendRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runtimeRoot 'api.stdout.log') -RedirectStandardError (Join-Path $runtimeRoot 'api.stderr.log') | Out-Null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if (Test-LocalPort 3000) { break }
        Start-Sleep -Seconds 1
    }
}
$health = Invoke-RestMethod 'http://localhost:3000/api/health'
if ($health.status -ne 'ok') { throw 'API chưa sẵn sàng' }
Write-Output 'MyFAP API sẵn sàng: http://localhost:3000/api (MySQL portable: 13379)'
