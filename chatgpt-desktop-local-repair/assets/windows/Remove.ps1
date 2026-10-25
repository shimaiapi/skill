$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$marker=Join-Path $root 'installation.json'
if(-not(Test-Path $marker)){throw 'Missing ownership marker. Nothing removed.'}
$record=Get-Content -Raw $marker | ConvertFrom-Json
if($record.owner -ne 'chatgpt-desktop-local-repair'){throw 'Unexpected owner. Nothing removed.'}
$script=Join-Path $root 'proxy.cjs'
$helpers=@(Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains($script)})
# Do not interrupt an app still using this helper.
$running=@(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe' OR Name='Codex.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains('--proxy-pac-url=http://127.0.0.1:18769/proxy.pac')})
if($running.Count -and $helpers.Count){throw 'Exit the app (including tray) before removing the helper.'}
$helpers | ForEach-Object {Stop-Process -Id $_.ProcessId -Force}
if($record.shortcut -and (Test-Path -LiteralPath $record.shortcut)){
    $wsh=New-Object -ComObject WScript.Shell
    $link=$wsh.CreateShortcut($record.shortcut)
    if($link.Arguments.Contains((Join-Path $root 'Launch.ps1'))){Remove-Item -LiteralPath $record.shortcut -Force}
}
Remove-Item -LiteralPath $root -Recurse -Force
Write-Output 'Helper removed. Use the original official application shortcut.'
