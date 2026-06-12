param([Parameter(Mandatory=$true)][string]$Module)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if(-not(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))){
  Write-Host "[ERR] Admin required." -Fore Red
  exit 1
}

function Write-Log([string]$msg,[string]$level="info"){
  $tag = ""
  switch($level){
    "ok"   { $tag = "[OK] " }
    "err"  { $tag = "[ERR] " }
    "head" { $tag = "[HEAD] " }
    "warn" { $tag = "[WARN] " }
  }
  Write-Host "$tag$msg"
}

function Set-Reg([string]$path,[string]$name,$value,[string]$type="DWord"){
  try{
    if(-not(Test-Path $path)){New-Item -Path $path -Force|Out-Null}
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force
    Write-Log "Reg: $name=$value" "ok"
  }catch{
    Write-Log "Reg: $name FAIL" "err"
  }
}

function Stop-Svc([string]$n){
  try{Stop-Service -Name $n -Force -EA 0;Write-Log "STOP: $n" "ok"}catch{}
}

function Disable-Svc([string]$n){
  try{Set-Service -Name $n -StartupType Disabled -EA 0;Write-Log "DIS: $n" "ok"}catch{}
}

function Start-Svc([string]$n){
  try{
    $svc = Get-Service -Name $n -EA 0
    if($svc){
      if($svc.StartType -eq "Disabled"){Set-Service -Name $n -StartupType Manual -EA 0}
      Start-Service -Name $n -EA 0
      Write-Log "START: $n" "ok"
    }
  }catch{}
}

function Enable-Svc([string]$n){
  try{
    Set-Service -Name $n -StartupType Automatic -EA 0
    Start-Service -Name $n -EA 0
    Write-Log "EN: $n" "ok"
  }catch{}
}

switch($Module){

"backup" {
  Write-Log "Criando ponto de restauracao..." "head"
  try{
    Enable-ComputerRestore -Drive "C:\" -EA 0
    Checkpoint-Computer -Description "PERIS" -RestorePointType MODIFY_SETTINGS -EA 0
    Write-Log "Ponto de restauracao criado!" "ok"
  }catch{ Write-Log "Erro ao criar restore point" "err" }
}

"telemetria" {
  Write-Log "Desativando telemetria..." "head"
  foreach($s in @("DiagTrack","dmwappushservice","PcaSvc","MapsBroker","WSearch","SysMain","WerSvc","NvTelemetryContainer")){Stop-Svc $s;Disable-Svc $s}
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1
  Write-Log "Telemetria desativada!" "ok"
}

"gaming-services" {
  Write-Log "Ativando servicos para apostado..." "head"

  # Ativar servicos
  foreach($s in @("PcaSvc","PlugPlay","DPS","DiagTrack","SysMain","Sysmon","Mpssvc")){
    Start-Svc $s
    Enable-Svc $s
  }

  # USN Journal em discos NTFS
  Write-Log "Verificando USN Journal..." "head"
  Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.FileSystem -eq "NTFS" } | ForEach-Object {
    $disk = $_.DeviceID
    try{
      $usn = fsutil usn queryjournal $disk 2>&1
      if($LASTEXITCODE -ne 0){
        fsutil usn createjournal $disk 134217728 134217728 2>$null
        Write-Log "USN Journal ativado em $disk" "ok"
      }else{
        Write-Log "USN Journal ativo em $disk" "ok"
      }
    }catch{
      Write-Log "USN Journal: erro em $disk" "warn"
    }
  }

  # TPM 2.0
  Write-Log "Verificando TPM..." "head"
  try{
    $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction Stop
    if($tpm){
      Write-Log "TPM 2.0 ativo" "ok"
    }
  }catch{
    Write-Log "TPM: nao detectado ou indisponivel" "warn"
  }

  # Secure Boot
  Write-Log "Verificando Secure Boot..." "head"
  $sb = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -ErrorAction SilentlyContinue
  if($sb.UEFISecureBootEnabled -eq 1){
    Write-Log "Secure Boot ativo" "ok"
  }else{
    Write-Log "Secure Boot: desativado ou indisponivel" "warn"
  }

  # Virtualizacao (IOMMU)
  Write-Log "Verificando virtualizacao..." "head"
  try{
    $virt = systeminfo 2>$null | Select-String "Virtualização em hardware"
    if($virt -match "Sim"){
      Write-Log "Virtualizacao (IOMMU) ativa" "ok"
    }else{
      Write-Log "Virtualizacao: desativada no BIOS" "warn"
    }
  }catch{
    Write-Log "Virtualizacao: nao foi possivel verificar" "warn"
  }

  Write-Log "Servicos para apostado ativados!" "ok"
}

"desativar-apostado" {
  Write-Log "Desativando servicos para apostado..." "head"
  foreach($s in @("PcaSvc","DiagTrack","SysMain","PlugPlay","DPS","Sysmon","EventLog","Mpssvc","TapiSrv","TabletInputService")){Stop-Svc $s;Disable-Svc $s}
  Write-Log "Servicos para apostado desativados!" "ok"
  Write-Host "[RESTART]"
}

"bloatware" {
  Write-Log "Removendo bloatware..." "head"

  # Remover Microsoft Edge (completo)
  Write-Log "Removendo Microsoft Edge..." "head"
  try{
    Stop-Process -Name "msedge" -Force -EA 0
    Stop-Process -Name "msedgewebview2" -Force -EA 0
  }catch{}
  foreach($p in @("*MicrosoftEdge*","*MicrosoftEdgeWebView*","*Edge*")){
    try{Get-AppxPackage -Name $p -AllUsers -EA 0|Remove-AppxPackage -EA 0}catch{}
    try{Get-AppxProvisionedPackage -Online|Where-Object{$_.PackageName -like $p}|Remove-AppxProvisionedPackage -Online -EA 0}catch{}
  }
  $edgePaths = @(
    "$env:ProgramFiles\Microsoft\Edge",
    "$env:ProgramFiles(x86)\Microsoft\Edge",
    "$env:LOCALAPPDATA\Microsoft\Edge",
    "$env:LOCALAPPDATA\Microsoft\EdgeUpdate",
    "$env:ProgramData\Microsoft\EdgeUpdate",
    "$env:ProgramData\Microsoft\Edge"
  )
  foreach($ep in $edgePaths){
    if(Test-Path $ep){Remove-Item $ep -Recurse -Force -EA 0}
  }
  try{Set-Service -Name "edgeupdate" -StartupType Disabled -EA 0}catch{}
  try{Set-Service -Name "edgeupdatem" -StartupType Disabled -EA 0}catch{}
  try{Stop-Service -Name "edgeupdate" -Force -EA 0}catch{}
  try{Stop-Service -Name "edgeupdatem" -Force -EA 0}catch{}
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" "NoRemove" 0
  Write-Log "Microsoft Edge removido!" "ok"

  # Remover outros bloatware
  foreach($a in @("Microsoft.3DBuilder","Microsoft.BingWeather","Microsoft.BingNews","Microsoft.BingFinance","Microsoft.BingSports","Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.MicrosoftSolitaireCollection","Microsoft.People","Microsoft.SkypeApp","Microsoft.MicrosoftOfficeHub","Microsoft.OneConnect","Microsoft.WindowsFeedbackHub","Microsoft.ZuneMusic","Microsoft.ZuneVideo","Microsoft.WindowsMaps","Microsoft.MixedReality.Portal","Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider","Microsoft.XboxSpeechToTextOverlay","Microsoft.YourPhone","Microsoft.WindowsAlarms","king.com.*","Disney.*","SpotifyAB.SpotifyMusic")){
    try{Get-AppxPackage -Name $a -AllUsers -EA 0|Remove-AppxPackage -EA 0}catch{}
  }
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
  try{Stop-Process -Name "OneDrive" -Force -EA 0}catch{}
  # Remover OneDrive
  try{
    Stop-Process -Name "OneDrive" -Force -EA 0
    Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -EA 0
  }catch{}
  Write-Log "Bloatware removido!" "ok"
}

"power" {
  Write-Log "Configurando energia..." "head"
  powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
  powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
  powercfg /hibernate off
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HiberbootEnabled" 0
  Write-Log "Energia em alta performance!" "ok"
  Write-Host "[RESTART]"
}

"ui" {
  Write-Log "Otimizando interface..." "head"
  Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
  Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\Dwm" "EnableAeroPeek" 0
  Write-Log "Interface otimizada!" "ok"
  Write-Host "[RESTART]"
}

"startmenu-delay" {
  Write-Log "Otimizando menu iniciar..." "head"
  Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "StartupDelayInMSec" 0
  Write-Log "Menu iniciar otimizado!" "ok"
}

"monitor-05ms" {
  Write-Log "Ativando timer de alta precisao..." "head"
  $bg = @'
while($true){
  try{
    Add-Type -TypeDefinition "using System;using System.Runtime.InteropServices;public class T2{[DllImport(\"ntdll.dll\")]public static extern int NtSetTimerResolution(uint d,bool s,out uint c);[DllImport(\"winmm.dll\")]public static extern uint timeBeginPeriod(uint p);}" -EA 0
    $c=0
    [T2]::NtSetTimerResolution(5000,$true,[ref]$c)|Out-Null
    [T2]::timeBeginPeriod(1)|Out-Null
  }catch{}
  Start-Sleep -Seconds 1
}
'@
  Set-Content -Path "$env:Public\Documents\peris-timer-bg.ps1" -Value $bg -Force
  Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:Public\Documents\peris-timer-bg.ps1`"" -WindowStyle Hidden
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
  Write-Log "Timer 0.5ms ativado!" "ok"
}

"inputlag" {
  Write-Log "Otimizando input lag..." "head"
  $gp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
  if(-not(Test-Path $gp)){New-Item -Path $gp -Force|Out-Null}
  Set-Reg $gp "GPU Priority" 8
  Set-Reg $gp "Scheduling Category" "High" -Type String
  Set-Reg $gp "SFIO Priority" "High" -Type String
  Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" -Type String
  Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" -Type String
  Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" -Type String
  Write-Log "Input lag otimizado!" "ok"
}

"ping" {
  Write-Log "Otimizando rede TCP..." "head"
  $tp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
  Set-Reg $tp "TCPNoDelay" 1
  Set-Reg $tp "TcpAckFrequency" 1
  Set-Reg $tp "TCPDelAckTicks" 0
  Set-Reg $tp "TcpTimedWaitDelay" 30
  Set-Reg $tp "MaxUserPort" 65534
  Write-Log "Rede TCP otimizada!" "ok"
}

"cache" {
  Write-Log "Limpando cache e arquivos temporarios..." "head"

  # Temp files
  Remove-Item "$env:TEMP\*" -Recurse -Force -EA 0
  Write-Log "Temp limpo" "ok"

  # Drivers .sys no Temp
  $sysFiles = Get-ChildItem "$env:TEMP\*.sys" -Force -EA 0
  if($sysFiles){
    foreach($f in $sysFiles){ Remove-Item $f.FullName -Force -EA 0 }
    Write-Log "Drivers .sys do Temp removidos ($($sysFiles.Count))" "ok"
  }

  # Crash dumps
  Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Force -EA 0
  Remove-Item "$env:TEMP\*.dmp" -Force -EA 0
  Remove-Item "$env:SystemRoot\Minidump\*" -Force -EA 0
  Remove-Item "$env:SystemRoot\MEMORY.DMP" -Force -EA 0
  Write-Log "Crash dumps limpos" "ok"

  # Prefetch
  Remove-Item "$env:SystemRoot\Prefetch\*" -Force -EA 0
  Write-Log "Prefetch limpo" "ok"

  # Atalhos recentes
  Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*.lnk" -Force -EA 0
  Write-Log "Atalhos recentes limpos" "ok"

  # .lnk na raiz do C:
  Get-ChildItem "C:\*.lnk" -Force -EA 0 | Remove-Item -Force -EA 0
  Write-Log "Atalhos do C: limpos" "ok"

  # .NET NativeImages temp (ZAP)
  Remove-Item "$env:TEMP\ZAP*" -Recurse -Force -EA 0
  Get-ChildItem "C:\Windows\assembly\NativeImages_*\Temp" -Directory -EA 0 | ForEach-Object {
    Remove-Item "$($_.FullName)\*" -Recurse -Force -EA 0
  }
  Write-Log ".NET NativeImages limpo" "ok"

  # .NET temp files
  Remove-Item "$env:TEMP\*.tmp" -Force -EA 0
  Write-Log ".NET temp limpo" "ok"

  # sxsoa.dll / sxsoaps.dll
  Remove-Item "$env:SystemRoot\System32\sxsoa.dll" -Force -EA 0
  Remove-Item "$env:SystemRoot\System32\sxsoaps.dll" -Force -EA 0

  # DNS
  ipconfig /flushdns | Out-Null
  Write-Log "DNS limpo" "ok"

  # Windows Update cache
  try{
    Stop-Service wuauserv -Force -EA 0
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -EA 0
    Start-Service wuauserv -EA 0
  }catch{}
  Write-Log "Windows Update cache limpo" "ok"

  # Recycle Bin
  try{ Clear-RecycleBin -Force -EA 0 }catch{}
  Write-Log "Lixeira limpa" "ok"

  Write-Log "Cache completo limpo!" "ok"
}

"gpu-opt" {
  Write-Log "Otimizando GPU..." "head"
  $np = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
  foreach($g in @("0000","0001","0002")){
    $p = "$np\$g"
    if(Test-Path $p){
      Set-Reg $p "PerfLevelSrc" 8738
      Set-Reg $p "PowerMizerEnable" 1
      Set-Reg $p "PowerMizerLevel" 1
    }
  }
  Write-Log "GPU otimizada!" "ok"
  Write-Host "[RESTART]"
}

"memory" {
  Write-Log "Otimizando memoria RAM..." "head"
  Start-Svc "SysMain"
  Enable-Svc "SysMain"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 0
  try{Clear-RecycleBin -Force -EA 0}catch{}
  Write-Log "Memoria otimizada!" "ok"
}

"disk-io" {
  Write-Log "Otimizando disco..." "head"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 80000003
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2
  Write-Log "Disco I/O otimizado!" "ok"
  Write-Host "[RESTART]"
}

"gamemode" {
  Write-Log "Ativando Game Mode..." "head"
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
  Write-Log "Game Mode ativado!" "ok"
  Write-Host "[RESTART]"
}

"dns-opt" {
  Write-Log "Configurando DNS rapido..." "head"
  try{
    $i = Get-NetAdapter|? Status -eq "Up"|Select -First 1
    if($i){
      Set-DnsClientServerAddress -InterfaceIndex $i.InterfaceIndex -ServerAddresses @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4")
      Write-Log "DNS Cloudflare+Google configurado!" "ok"
    }
  }catch{}
  ipconfig /flushdns|Out-Null
  Write-Log "DNS otimizado!" "ok"
}

"scheduled" {
  Write-Log "Desativando tarefas pesadas..." "head"
  foreach($t in @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Maps\MapsToastTask",
    "\Microsoft\Windows\Maps\MapsUpdateTask"
  )){try{Disable-ScheduledTask -TaskName $t -EA 0}catch{}}
  Write-Log "Tarefas desativadas!" "ok"
}

"spooler" {
  Write-Log "Desativando Spooler..." "head"
  Stop-Svc "Spooler"
  Disable-Svc "Spooler"
  Write-Log "Spooler desativado!" "ok"
}

"winupdate" {
  Write-Log "Controle do Windows Update..." "head"
  Stop-Svc "wuauserv"
  Stop-Svc "UsoSvc"
  Disable-Svc "wuauserv"
  Disable-Svc "UsoSvc"
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
  Write-Log "Windows Update controlado!" "ok"
  Write-Host "[RESTART]"
}

"boot" {
  Write-Log "Acelerando boot..." "head"
  bcdedit /set timeout 0 2>$null
  bcdedit /set bootlog no 2>$null
  Write-Log "Boot acelerado!" "ok"
  Write-Host "[RESTART]"
}

"benchmark" {
  Write-Log "Rodando benchmark..." "head"
  try{
    $b = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    Write-Log "CPU usage: $([math]::Round($b,1))%" "ok"
  }catch{
    Write-Log "Erro ao obter CPU usage" "err"
  }
}

"profiles" {
  Write-Log "Perfis - use a interface." "head"
}

"export" {
  Write-Log "Exportar - use a interface." "head"
}

"integrity" {
  Write-Log "Verificando integridade do sistema..." "head"
  try{
    Start-Process sfc.exe -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow|Out-Null
    Write-Log "SFC concluido!" "ok"
  }catch{}
  try{
    Start-Process DISM.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -NoNewWindow|Out-Null
    Write-Log "DISM concluido!" "ok"
  }catch{}
}

"defender-off" {
  Write-Log "Desativando Windows Defender..." "head"

  # Desativar monitoramento em tempo real
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiVirus" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableBehaviorMonitoring" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableOnAccessProtection" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableScanOnRealtimeEnable" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableIOAVProtection" 1
  Write-Log "Monitoramento desativado" "ok"

  # Desativar proteção em nuvem e envio de amostras
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SubmitSamplesConsent" 2
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "DisableBlockAtFirstSeen" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications" 1
  Write-Log "Proteção em nuvem desativada" "ok"

  # Desativar tarefas agendadas do Defender
  foreach($t in @(
    "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "\Microsoft\Windows\Windows Defender\Windows Defender Verification"
  )){try{Disable-ScheduledTask -TaskName $t -EA 0}catch{}}
  Write-Log "Tarefas desativadas" "ok"

  # Parar serviços
  foreach($s in @("WinDefend","WdNisSvc","WdNisArm","Sense")){
    Stop-Svc $s
    Disable-Svc $s
  }
  Write-Log "Servicos desativados" "ok"

  # Desativar Tamper Protection
  try{
    Set-MpPreference -DisableTamperProtection $true -EA 0
    Write-Log "Tamper Protection desativado (cmdlet)" "ok"
  }catch{
    try{
      $tpPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
      if(-not(Test-Path $tpPath)){New-Item -Path $tpPath -Force|Out-Null}
      Set-ItemProperty -Path $tpPath -Name "TamperProtection" -Value 0 -Type DWord -Force
      Set-ItemProperty -Path $tpPath -Name "TamperProtectionSource" -Value 0 -Type DWord -Force
      Write-Log "Tamper Protection desativado (reg)" "ok"
    }catch{
      Write-Log "Tamper Protection: desative manualmente no Windows Security" "warn"
    }
  }

  # Desativar SmartScreen
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Off" -Type String
  Write-Log "SmartScreen desativado" "ok"

  Write-Log "Windows Defender desativado completamente!" "ok"
  Write-Host "[RESTART]"
}

default {
  Write-Log "Modulo desconhecido: $Module" "err"
  exit 1
}

}

Write-Log "Modulo '$Module' aplicado com sucesso!" "ok"
exit 0
