$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$localRoot = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Force -Path $localRoot | Out-Null
if (!(Test-Path -LiteralPath (Join-Path $backendRoot '.env'))) { Copy-Item -LiteralPath (Join-Path $backendRoot '.env.example') -Destination (Join-Path $backendRoot '.env') }
function Test-LocalPort([int]$Port) {
    $client = [Net.Sockets.TcpClient]::new()
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $client.Dispose() }
}
if (!(Test-LocalPort 27018)) {
    $mongoExe = $env:MONGOD_EXE
    if (!$mongoExe) { $command = Get-Command mongod.exe -ErrorAction SilentlyContinue; if ($command) { $mongoExe = $command.Source } }
    if (!$mongoExe) { $candidate = Get-ChildItem 'C:\Program Files\MongoDB\Server\*\bin\mongod.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1; if ($candidate) { $mongoExe = $candidate.FullName } }
    if (!$mongoExe -or !(Test-Path -LiteralPath $mongoExe)) { throw 'Cần MongoDB Server, hoặc chạy docker compose up -d --wait trước.' }
    $dataPath = Join-Path $localRoot 'mongo-data'
    New-Item -ItemType Directory -Force -Path $dataPath | Out-Null
    $arguments = @('--replSet', 'myfap-rs', '--bind_ip', '127.0.0.1', '--port', '27018', ('--dbpath="{0}"' -f $dataPath), ('--logpath="{0}"' -f (Join-Path $localRoot 'mongo.log')), '--logappend')
    Start-Process -FilePath $mongoExe -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    for ($attempt = 0; $attempt -lt 30; $attempt++) { if (Test-LocalPort 27018) { break }; Start-Sleep -Seconds 1 }
    if (!(Test-LocalPort 27018)) { throw 'MongoDB chưa khởi động được. Xem .local/mongo.log.' }
}
Push-Location $backendRoot
try {
    & node --env-file=.env src/init-replica.js
    if ($LASTEXITCODE -ne 0) { throw 'Replica set chưa sẵn sàng' }
    & node --env-file=.env src/init-db.js
    if ($LASTEXITCODE -ne 0) { throw 'Không khởi tạo được MongoDB' }
    if (!(Test-LocalPort 3000)) {
        Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList @('--env-file=.env', 'src/server.js') -WorkingDirectory $backendRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $localRoot 'api.stdout.log') -RedirectStandardError (Join-Path $localRoot 'api.stderr.log') | Out-Null
        for ($attempt = 0; $attempt -lt 20; $attempt++) { if (Test-LocalPort 3000) { break }; Start-Sleep -Seconds 1 }
    }
} finally { Pop-Location }
$health = Invoke-RestMethod 'http://localhost:3000/api/health'
if ($health.status -ne 'ok' -or $health.database -ne 'mongodb') { throw 'API cổng 3000 chưa dùng MongoDB đúng cấu hình' }
Write-Output 'MyFAP Express/Mongoose: http://localhost:3000/api | MongoDB replica set: 127.0.0.1:27018'
