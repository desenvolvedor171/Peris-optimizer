param([Parameter(Mandatory=$true)][string[]]$Modules)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"
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

function Remove-Reg([string]$path,[string]$name){
  try{
    if(Test-Path $path){
      Remove-ItemProperty -Path $path -Name $name -Force -EA 0
      Write-Log "Reg removido: $name" "ok"
    }
  }catch{}
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

Write-Log "Revertendo modulos..." "head"

foreach($mod in $Modules){

  switch($mod){

  "telemetria" {
    Write-Log "Revertendo Telemetria + Cortana + Widgets + Copilot + Teams..." "head"

    # Reativar servicos
    foreach($s in @("dmwappushservice","MapsBroker","WSearch","WerSvc")){
      Enable-Svc $s
    }

    # Restaurar telemetria
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled"

    # Restaurar SmartScreen
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 1

    # Restaurar Cortana
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled"

    # Restaurar Widgets
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Widgets" "AllowWidgets"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 1 -Type DWord

    # Restaurar Copilot
    Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsCopilot" "AllowCopilot"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"

    # Restaurar Teams
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Teams" "AllowMSTeams"

    Write-Log "Telemetria revertida!" "ok"
  }

  "gaming-services" {
    Write-Log "Revertendo Servicos para apostado..." "head"
    # Gaming services only enables things, so we just stop non-essential ones
    Write-Log "Servicos mantidos (apenas habilitacao)" "ok"
  }

  "desativar-apostado" {
    Write-Log "Revertendo Otimizacao Agressiva..." "head"

    # Reativar todos os servicos desativados
    foreach($s in @(
      "PcaSvc","DiagTrack","SysMain","PlugPlay","DPS","Sysmon","EventLog","Mpssvc","TapiSrv",
      "WSearch","wuauserv","UsoSvc","BITS","SecurityHealthService","SDRSVC","WbioSrvc",
      "RemoteRegistry","RetailDemo","Fax","MapsBroker","lfsvc","SharedAccess","DsSvc",
      "WerSvc","seclogon","WpcMonSvc","ScDeviceEnum","CscService","wisvc",
      "DoSvc","TrkWks","WdiServiceHost","WdiSystemHost","SCardSvr","SEMGRSVC",
      "AppXSvc","ClipSVC","InstallService","TokenBroker","wbengine","DsmSvc",
      "DusmSvc","PhoneSvc","XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc"
    )){Enable-Svc $s}

    # Reativar tarefas agendadas
    foreach($t in @(
      "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
      "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
      "\Microsoft\Windows\Autochk\Proxy",
      "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
      "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
      "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
      "\Microsoft\Windows\Feedback\Siuf\DmClient",
      "\Microsoft\Windows\Maps\MapsUpdateTask",
      "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
      "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
      "\Microsoft\Windows\DiskFootprint\Diagnostics",
      "\Microsoft\Windows\PI\Sqm-Tasks",
      "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
      "\Microsoft\Windows\Shell\FamilySafetyMonitor",
      "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
      "\Microsoft\Windows\UPI\SIpuTask",
      "\Microsoft\Windows\WCM\WiFiTask",
      "\Microsoft\Windows\Windows Filtering Platform\BlockedConnections"
    )){try{schtasks /Change /TN $t /Enable 2>$null}catch{}}

    # Restaurar efeitos visuais
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "1" -Type String
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow"
    Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" "1" -Type String
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" -Type String

    # Restaurar notificacoes e icones
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn"
    Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableNotificationCenter"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled"

    # Restaurar OneDrive
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSynCG"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudButton"

    Write-Log "Otimizacao Agressiva revertida!" "ok"
    Write-Host "[RESTART]"
  }

  "bloatware" {
    Write-Log "Revertendo Bloatware..." "head"
    Write-Log "Apps removidos nao podem ser restaurados pelo painel" "warn"
    Write-Log "Restaurando configuracoes de fundo..." "ok"
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Teams" "AllowMSTeams"
    Write-Log "Bloatware revertido (configs)!" "ok"
  }

  "power" {
    Write-Log "Revertendo Plano de Energia..." "head"
    # Restaurar plano equilibrado
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    powercfg /hibernate on
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HiberbootEnabled" 1
    Write-Log "Energia restaurada (Equilibrado)!" "ok"
  }

  "ui" {
    Write-Log "Revertendo Interface..." "head"
    # Restaurar animacoes
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" -Type String
    Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "1" -Type String
    Set-Reg "HKCU:\Software\Microsoft\Windows\Dwm" "EnableAeroPeek" 1

    # Restaurar transparencia
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1

    # Restaurar snapping
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapAssist" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapFill" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapBar" 1

    # Desativar modo noturno
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default\$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings" "Data" ([byte[]](0x08,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01)) -Type Binary

    Write-Log "Interface revertida!" "ok"
  }

  "startmenu-delay" {
    Write-Log "Revertendo Menu Iniciar..." "head"
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" -Type String
    Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "StartupDelayInMSec"
    Write-Log "Menu Iniciar revertido!" "ok"
  }

  "monitor-05ms" {
    Write-Log "Revertendo Timer 0.5ms + HPET..." "head"

    # 1) Matar processo do timer PRIMEIRO (para nao reaplicar a cada 500ms)
    $killed = Get-Process powershell -EA 0 | Where-Object {
      try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA 0).CommandLine
        $cmd -and $cmd -match "peris-timer"
      } catch { $false }
    }
    if($killed){
      $killed | Stop-Process -Force -EA 0
      Write-Log "Processo do timer morto (PID: $($killed.Id -join ', '))" "ok"
    }
    Remove-Item "$env:Public\Documents\peris-timer-bg.ps1" -Force -EA 0

    # 2) Remover tarefa agendada
    Unregister-ScheduledTask -TaskName "PerisTimerResolution" -Confirm:$false -EA 0
    Write-Log "Tarefa agendada removida" "ok"

    # 3) Resetar timer resolution para padrao (15.625ms = 156250 em units de 100ns)
    Write-Log "Resetando timer resolution para 1ms..." "info"
    try{
      Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TimerReset {
    [DllImport("ntdll.dll")]
    public static extern int NtSetTimerResolution(uint desiredResolution, bool setResolution, out uint currentResolution);
    [DllImport("winmm.dll")]
    public static extern uint timeEndPeriod(uint period);
}
"@ -EA 0
      $res = [uint32]0
      [TimerReset]::NtSetTimerResolution(10000, $true, [ref]$res) | Out-Null
      [TimerReset]::timeEndPeriod(1) | Out-Null
      Write-Log "Timer resolution resetado para 1ms (padrao)" "ok"
    }catch{
      Write-Log "Falha ao resetar timer via API" "warn"
    }

    # 4) Restaurar registry
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 20
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "InterruptSteeringDisabled"
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation"

    # 5) Restaurar HPET
    $null = & bcdedit /set useplatformtick no 2>&1
    $null = & bcdedit /set disabledynamictick no 2>&1

    Write-Log "Timer + HPET revertidos!" "ok"
  }

  "inputlag" {
    Write-Log "Revertendo Input Lag..." "head"
    # Restaurar mouse
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" -Type String
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "6" -Type String
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "10" -Type String

    # Restaurar GPU priority
    $gp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Remove-Reg $gp "GPU Priority"
    Remove-Reg $gp "Scheduling Category"
    Remove-Reg $gp "SFIO Priority"

    Write-Log "Input Lag revertido!" "ok"
  }

  "ping" {
    Write-Log "Revertendo Rede / TCP..." "head"
    $tp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

    # Restaurar TCP defaults
    Remove-Reg $tp "TCPNoDelay"
    Remove-Reg $tp "TcpAckFrequency"
    Remove-Reg $tp "TCPDelAckTicks"
    Set-Reg $tp "TcpTimedWaitDelay" 120
    Set-Reg $tp "MaxUserPort" 5000

    # Restaurar throttling
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "DisableBandwidthThrottling"
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters" "FastSendDatagramThreshold"
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters" "FastCopyReceiveThreshold"

    # Remover DoH
    try{
      $adapter = Get-NetAdapter|Where-Object Status -eq "Up"|Select-Object -First 1
      if($adapter){
        Set-DnsClientDoh -InterfaceIndex $adapter.InterfaceIndex -ServerAddress "1.1.1.1" -Validate:0 -EA 0
        Set-DnsClientDoh -InterfaceIndex $adapter.InterfaceIndex -ServerAddress "8.8.8.8" -Validate:0 -EA 0
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @() -EA 0
      }
    }catch{}

    ipconfig /flushdns|Out-Null
    Write-Log "Rede revertida!" "ok"
  }

  "cache" {
    Write-Log "Cache: arquivos limpos nao podem ser restaurados" "warn"
  }

  "gpu-opt" {
    Write-Log "Revertendo GPU..." "head"
    $np = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    foreach($g in @("0000","0001","0002")){
      $p = "$np\$g"
      if(Test-Path $p){
        Remove-Reg $p "PerfLevelSrc"
        Remove-Reg $p "PowerMizerEnable"
        Remove-Reg $p "PowerMizerLevel"
      }
    }
    Write-Log "GPU revertida!" "ok"
    Write-Host "[RESTART]"
  }

  "memory" {
    Write-Log "Revertendo Memoria RAM..." "head"
    # Reativar compressao
    try{
      Enable-MMAgent -MemoryCompression -EA 0
      Write-Log "Compressao reativada" "ok"
    }catch{
      Write-Log "Compressao: erro ao reativar" "warn"
    }

    # Restaurar registry
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 0

    Write-Log "Memoria revertida!" "ok"
  }

  "disk-io" {
    Write-Log "Revertendo Disco I/O..." "head"
    # Restaurar NTFS
    Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1

    # Reativar indexacao
    try{
      Set-Service "WSearch" -StartupType Automatic -EA 0
      Start-Service "WSearch" -EA 0
      Write-Log "Windows Search reativado" "ok"
    }catch{
      Write-Log "WSearch: erro ao reativar" "warn"
    }

    Write-Log "Disco I/O revertido!" "ok"
  }

  "gamemode" {
    Write-Log "Revertendo Game Mode..." "head"
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode"
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR"
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1

    # Restaurar Game Bar
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel"
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "GamePanelStartupState"
    Remove-Reg "HKCU:\Software\Microsoft\GameBar" "UseSteamOverlay"

    Write-Log "Game Mode revertido!" "ok"
  }

  "dns-opt" {
    Write-Log "Revertendo DNS..." "head"
    try{
      $i = Get-NetAdapter|? Status -eq "Up"|Select -First 1
      if($i){
        Set-DnsClientServerAddress -InterfaceIndex $i.InterfaceIndex -ResetServerAddresses -EA 0
        Write-Log "DNS restaurado (DHCP)" "ok"
      }
    }catch{}
    ipconfig /flushdns|Out-Null
    Write-Log "DNS revertido!" "ok"
  }

  "scheduled" {
    Write-Log "Revertendo Tarefas Agendadas..." "head"
    foreach($t in @(
      "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
      "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
      "\Microsoft\Windows\Autochk\Proxy",
      "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
      "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
      "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
      "\Microsoft\Windows\Maps\MapsToastTask",
      "\Microsoft\Windows\Maps\MapsUpdateTask"
    )){try{Enable-ScheduledTask -TaskName $t -EA 0}catch{}}
    Write-Log "Tarefas reativadas!" "ok"
  }

  "spooler" {
    Write-Log "Revertendo Spooler..." "head"
    Enable-Svc "Spooler"
    Write-Log "Spooler reativado!" "ok"
  }

  "winupdate" {
    Write-Log "Revertendo Windows Update..." "head"
    Enable-Svc "wuauserv"
    Enable-Svc "UsoSvc"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate"
    Write-Log "Windows Update reativado!" "ok"
  }

  "boot" {
    Write-Log "Revertendo Boot..." "head"
    bcdedit /set timeout 30 2>$null
    bcdedit /set bootlog yes 2>$null
    Write-Log "Boot revertido!" "ok"
    Write-Host "[RESTART]"
  }

  "defender-off" {
    Write-Log "Revertendo Windows Defender..." "head"

    # Reativar monitoramento
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiVirus"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableBehaviorMonitoring"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableOnAccessProtection"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableScanOnRealtimeEnable"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableIOAVProtection"

    # Reativar protecao em nuvem
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SubmitSamplesConsent"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "DisableBlockAtFirstSeen"
    Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications"

    # Reativar tarefas
    foreach($t in @(
      "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
      "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
      "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
      "\Microsoft\Windows\Windows Defender\Windows Defender Verification"
    )){try{Enable-ScheduledTask -TaskName $t -EA 0}catch{}}

    # Reativar servicos
    foreach($s in @("WinDefend","WdNisSvc","WdNisArm")){
      Enable-Svc $s
    }

    # Reativar Tamper Protection
    try{
      Set-MpPreference -DisableTamperProtection $false -EA 0
      Write-Log "Tamper Protection reativado" "ok"
    }catch{
      Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" "TamperProtection"
      Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" "TamperProtectionSource"
    }

    # Reativar SmartScreen
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "RequireAdmin" -Type String

    Write-Log "Windows Defender reativado!" "ok"
    Write-Host "[RESTART]"
  }

  }

}

Write-Log "Todos os modulos revertidos com sucesso!" "ok"
exit 0
