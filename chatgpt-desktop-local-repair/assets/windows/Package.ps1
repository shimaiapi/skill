function Get-RepairPackage {
    $package=Get-AppxPackage -Name OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
    if(-not $package){throw 'No OpenAI.Codex MSIX package found. Other ChatGPT products/installers require a separate adapter.'}
    $manifest=Get-AppxPackageManifest $package
    $apps=@($manifest.Package.Applications.Application | Where-Object {$_.Executable -match '(^|[/\\])(ChatGPT|Codex)\.exe$'})
    if($apps.Count -ne 1){throw 'Application manifest changed or is ambiguous. Inspect it before adapting.'}
    $exe=Join-Path $package.InstallLocation ($apps[0].Executable.Replace('/',[char]92))
    if((Get-AuthenticodeSignature -LiteralPath $exe).Status -ne 'Valid'){throw 'Official application signature is not valid.'}
    $archive=Join-Path (Split-Path $exe) 'resources\app.asar'
    if(-not(Test-Path -LiteralPath $archive)){throw 'Electron ASAR layout changed. Inspect before adapting.'}
    [PSCustomObject]@{Package=$package;Application=$apps[0];Executable=$exe;Archive=$archive}
}
function Test-RepairAdapter($info,$node,$directory) {
    $version=$info.Package.Version.ToString()
    $cache=Join-Path $directory 'compatibility.json'
    $old=$null
    if(Test-Path $cache){try{$old=Get-Content -Raw $cache | ConvertFrom-Json}catch{}}
    # Version plus ASAR stamp invalidate the inexpensive cache after an update.
    $stamp=(Get-Item -LiteralPath $info.Archive).LastWriteTimeUtc.Ticks.ToString()+':'+(Get-Item -LiteralPath $info.Archive).Length
    if($old -and $old.packageVersion -eq $version -and $old.archiveStamp -eq $stamp -and $old.structureMatched){return $old}
    $raw=& $node (Join-Path $directory 'inspect.cjs') $info.Archive
    if($LASTEXITCODE -ne 0){throw 'This app version does not match the bundled adapter. No proxy/app launch was performed; inspect the new version.'}
    $report=$raw | ConvertFrom-Json
    $report | Add-Member packageVersion $version
    $report | Add-Member archiveStamp $stamp
    $report | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $cache
    return $report
}
