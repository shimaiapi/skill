param([switch]$CheckOnly,[switch]$NoShortcut,[string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'OpenAI\ChatGPTDesktopLocalRepair'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Package.ps1')
$node=(Get-Command node.exe -ErrorAction Stop).Source
$nodeVersion=& $node --version
$major=[int]($nodeVersion.TrimStart('v').Split('.')[0])
if($major -lt 18){throw 'Node.js 18 or newer is required. No global dependency installation is performed.'}
$info=Get-RepairPackage
$raw=& $node (Join-Path $PSScriptRoot 'inspect.cjs') $info.Archive
if($LASTEXITCODE -ne 0){throw 'Unknown application structure. Inspect the version and adapt before installing.'}
$compatibility=$raw | ConvertFrom-Json
if($CheckOnly){[PSCustomObject]@{Package=$info.Package.Name;Version=$info.Package.Version.ToString();Executable=$info.Executable;Compatibility=$compatibility} | ConvertTo-Json -Depth 8;return}
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
if($InstallRoot.TrimEnd('\') -eq $PSScriptRoot.TrimEnd('\')){throw 'Choose an install directory different from the source bundle.'}
$marker=Join-Path $InstallRoot 'installation.json'
if(Test-Path $InstallRoot){
    if(-not(Test-Path $marker)){throw 'Target exists without an ownership marker; choose an empty directory.'}
    if((Get-Content -Raw $marker | ConvertFrom-Json).owner -ne 'chatgpt-desktop-local-repair'){throw 'Target belongs to another installation.'}
    $active=@(Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains((Join-Path $InstallRoot 'proxy.cjs'))})
    if($active.Count){throw 'Existing helper is running. Exit the app and run Remove.ps1, then install again.'}
}else{New-Item -ItemType Directory -Path $InstallRoot | Out-Null}
# Restrict directory BEFORE creating a private key. No OS trust-store enrollment.
$acl=New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,(New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'),(New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'))){$acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')))}
Set-Acl -LiteralPath $InstallRoot -AclObject $acl
$shortcut=Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT 中文启动.lnk'
if(-not $NoShortcut -and (Test-Path $shortcut)){throw 'Shortcut already exists; preserve it or choose -NoShortcut.'}
$record=@{owner='chatgpt-desktop-local-repair';installedAt=(Get-Date).ToUniversalTime().ToString('o');shortcut=$null}
$record | ConvertTo-Json | Set-Content -Encoding UTF8 $marker
$files=@('Launch.ps1','Remove.ps1','Package.ps1','ProcessIdentity.ps1','inspect.cjs','certificate.cjs','proxy.cjs')
foreach($file in $files){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $InstallRoot $file) -Force}
$certificate=& $node (Join-Path $InstallRoot 'certificate.cjs') $InstallRoot
if($LASTEXITCODE -ne 0){throw 'Certificate generation failed.'}
$null=Test-RepairAdapter $info $node $InstallRoot
# CheckOnly does not start the app or proxy and needs no interactive desktop.
& (Join-Path $InstallRoot 'Launch.ps1') -CheckOnly
if(-not $NoShortcut){
    $wsh=New-Object -ComObject WScript.Shell
    $link=$wsh.CreateShortcut($shortcut)
    $link.TargetPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $InstallRoot 'Launch.ps1')+'"'
    $link.WorkingDirectory=$InstallRoot
    $link.IconLocation=$info.Executable+',0'
    $link.Description='Application-only local language repair; preserve Windows package identity'
    $link.Save()
    $record.shortcut=$shortcut
    $record | ConvertTo-Json | Set-Content -Encoding UTF8 $marker
}
[PSCustomObject]@{Installed=$InstallRoot;Shortcut=$record.shortcut;RuntimeVerified=$false;Next='Launch from the interactive desktop and verify Chinese UI plus Check for Updates.'} | ConvertTo-Json -Compress
