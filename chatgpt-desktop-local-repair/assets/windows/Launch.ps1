param([switch]$CheckOnly, [ValidateRange(0,65535)][int]$DiagnosticPort = 0)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
try {
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    . (Join-Path $root 'Package.ps1')
    $info = Get-RepairPackage
    $package = $info.Package
    $exe = $info.Executable
    $compatibility = Test-RepairAdapter $info $node $root
    & $node -e "const f=require('fs'),c=require('crypto');const x=new c.X509Certificate(f.readFileSync(process.argv[1]));if(Date.parse(x.validTo)-Date.now()<86400000)process.exit(2)" (Join-Path $root 'proxy-cert.pem')
    if($LASTEXITCODE -ne 0){throw 'Local certificate expired or expires within 24 hours. Re-run Install.ps1 after exiting the application.'}
    $pin = (& $node -e "const f=require('fs'),c=require('crypto');console.log(c.createHash('sha256').update(new c.X509Certificate(f.readFileSync(process.argv[1])).publicKey.export({type:'spki',format:'der'})).digest('base64'))" (Join-Path $root 'proxy-cert.pem')).Trim()
    if ($CheckOnly) {
        [PSCustomObject]@{PackageVersion=$package.Version.ToString();Executable=$exe;CertificatePin=$pin;Adapter=$compatibility.adapter;StructureMatched=$compatibility.structureMatched;SystemProxyChanged=$false;SystemCertificateInstalled=$false;LaunchMode='WindowsPackageContext';PackageFamily=$package.PackageFamilyName} | ConvertTo-Json -Compress
        return
    }
    $sessionId = (Get-Process -Id $PID).SessionId
    if($sessionId -eq 0){throw 'Launch in the signed-in desktop session, not the SSH/service session. Use an Interactive scheduled task for remote testing.'}
    $running = @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" | Where-Object {$_.SessionId -eq $sessionId -and $_.ExecutablePath -eq $exe})
    if ($running.Count) { throw '请先完全退出已打开的 Codex（包括托盘），再使用此入口启动。' }
    $health = $null
    try {$health = Invoke-RestMethod 'http://127.0.0.1:18769/health' -TimeoutSec 1} catch {}
    if ($health -and ($health.service -ne 'codex-app-local-language' -or $health.spki -ne $pin)) { throw 'Local port 18769 is occupied by a different service.' }
    if (-not $health) {
        $script = Join-Path $root 'proxy.cjs'
        $proxy = Start-Process -FilePath $node -ArgumentList @(('"'+$script+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'proxy.log') -RedirectStandardError (Join-Path $root 'proxy-error.log')
        Set-Content -LiteralPath (Join-Path $root 'proxy.pid') -Value $proxy.Id -Encoding ASCII
        for ($attempt=0;$attempt -lt 40;$attempt++) {
            Start-Sleep -Milliseconds 100
            try {$health=Invoke-RestMethod 'http://127.0.0.1:18769/health' -TimeoutSec 1;break} catch {}
            if ($proxy.HasExited) {throw 'Local language service could not start. See proxy-error.log.'}
        }
        if (-not $health -or $health.service -ne 'codex-app-local-language' -or $health.spki -ne $pin) {throw 'Local language service did not become ready.'}
    }
    # The app selects its existing user-data directory during its own startup.
    # This flag is also required by Chromium's per-key certificate exception.
    $profile = Join-Path $env:APPDATA 'Codex'
    $arguments = @('--proxy-pac-url=http://127.0.0.1:18769/proxy.pac',('--ignore-certificate-errors-spki-list='+$pin),('--user-data-dir="'+$profile+'"'))
    if ($DiagnosticPort -gt 0) { $arguments += '--remote-debugging-port='+$DiagnosticPort }
    $application = $info.Application
    # A bare EXE launch loses the MSIX identity required by the updater.
    # Keep the package identity while passing the application-only proxy flags.
    Invoke-CommandInDesktopPackage -PackageFamilyName $package.PackageFamilyName -AppId $application.Id -Command $exe -Args ($arguments -join ' ') -ErrorAction Stop | Out-Null
} catch {
    if ($CheckOnly) {throw}
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($_.Exception.Message,'ChatGPT 中文启动') | Out-Null
    exit 1
}
