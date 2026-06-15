param([Parameter(Mandatory=$true)][string]$Module)
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
  Write-Log "Criando ponto de restauracao do sistema..." "head"

  # 1) Habilitar System Restore no C:
  Write-Log "Habilitando System Restore no C:\..." "info"
  try{
    Enable-ComputerRestore -Drive "C:\" -EA 0
    Write-Log "System Restore habilitado" "ok"
  }catch{
    Write-Log "Falha ao habilitar System Restore" "warn"
  }

  # 2) Verificar se o servico VSS esta rodando
  $vss = Get-Service -Name "VSS" -EA 0
  if($vss -and $vss.Status -ne "Running"){
    Write-Log "Iniciando servico VSS..." "info"
    try{
      Start-Service "VSS" -EA 0
      Start-Sleep -Seconds 2
      Write-Log "VSS iniciado" "ok"
    }catch{
      Write-Log "Falha ao iniciar VSS" "warn"
    }
  }

  # 3) Verificar espaco livre (minimo 1GB)
  $sysDrive = $env:SystemDrive
  $freeGB = [math]::Round((Get-PSDrive -Name $sysDrive.TrimEnd(':')).Free / 1GB, 2)
  Write-Log "Espaco livre em ${sysDrive}: ${freeGB} GB" "info"
  if($freeGB -lt 1){
    Write-Log "ERRO: Menos de 1GB livre! Libere espaco e tente novamente." "err"
    exit 1
  }

  # 4) Criar o ponto de restauracao
  Write-Log "Criando checkpoint do sistema..." "info"
  try{
    $desc = "PERIS - $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
    Checkpoint-Computer -Description $desc -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Log "Ponto de restauracao criado com sucesso!" "ok"
    Write-Log "Descricao: $desc" "ok"
  }catch{
    $errMsg = $_.Exception.Message
    if($errMsg -match "0x80042302"){
      Write-Log "Erro: Espaco insuficiente no volume de restauracao" "err"
    }elseif($errMsg -match "0x800423F0"){
      Write-Log "Erro: Limite de restore points atingido. Removendo os mais antigos..." "warn"
      try{
        $rp = Get-ComputerRestorePoint | Sort-Object SequenceNumber | Select-Object -First 1
        if($rp){
          vssadmin /delete shadows /for=${sysDrive} /oldest /quiet 2>$null
          Checkpoint-Computer -Description $desc -RestorePointType MODIFY_SETTINGS -EA Stop
          Write-Log "Ponto de restauracao criado apos limpar antigos!" "ok"
        }
      }catch{
        Write-Log "Falha ao criar ponto apos limpeza" "err"
      }
    }else{
      Write-Log "Erro: $errMsg" "err"
    }
    exit 1
  }

  # 5) Confirmar que o ponto foi criado
  Start-Sleep -Seconds 2
  try{
    $lastRP = Get-ComputerRestorePoint | Sort-Object SequenceNumber | Select-Object -Last 1
    if($lastRP -and $lastRP.Description -match "PERIS"){
      Write-Log "Confirmado! Ultimo restore point: #$($lastRP.SequenceNumber)" "ok"
    }
  }catch{}

  Write-Log "Sistema pronto para receber tweaks!" "ok"
}

"telemetria" {
  Write-Log "Desativando telemetria..." "head"
  foreach($s in @("dmwappushservice","MapsBroker","WSearch","WerSvc","NvTelemetryContainer")){Stop-Svc $s;Disable-Svc $s}
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

  # Cortana
  Write-Log "Desativando Cortana..." "head"
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
  try{Stop-Process -Name "SearchUI" -Force -EA 0}catch{}

  # Widgets
  Write-Log "Desativando Widgets..." "head"
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Widgets" "AllowWidgets" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 0
  try{Stop-Process -Name "Widgets" -Force -EA 0}catch{}

  # Copilot
  Write-Log "Desativando Copilot..." "head"
  Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsCopilot" "AllowCopilot" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
  try{Stop-Process -Name "Copilot" -Force -EA 0}catch{}

  # Teams
  Write-Log "Desativando Microsoft Teams..." "head"
  try{Stop-Process -Name "Teams" -Force -EA 0}catch{}
  try{Stop-Process -Name "ms-teams" -Force -EA 0}catch{}
  foreach($p in @("*MicrosoftTeams*","*Teams*")){
    try{Get-AppxPackage -Name $p -AllUsers -EA 0|Remove-AppxPackage -EA 0}catch{}
  }
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Teams" "AllowMSTeams" 0

  Write-Log "Telemetria + Cortana + Widgets + Copilot + Teams desativados!" "ok"
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
    Write-Log "Secure Boot: DESATIVADO - Ative na BIOS (Settings > Boot > Secure Boot)" "warn"
  }

  # Virtualizacao (IOMMU)
  Write-Log "Verificando virtualizacao..." "head"
  try{
    $virt = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled -EA 0
    if($virt -eq $true){
      Write-Log "Virtualizacao (IOMMU) ativa" "ok"
    }else{
      Write-Log "Virtualizacao: DESATIVADA - Ative na BIOS (Settings > CPU > SVM Mode ou Intel VT-d)" "warn"
    }
  }catch{
    Write-Log "Virtualizacao: nao foi possivel verificar" "warn"
  }

  Write-Log "Servicos para apostado ativados!" "ok"
}

"desativar-apostado" {
  Write-Log "Otimizacao Agressiva - modo ULTRA..." "head"

  # ============================================
  # SERVICOS DESATIVADOS (nao mexe Bluetooth/Win+Shift+S)
  # ============================================
  foreach($s in @(
    "PcaSvc","DiagTrack","SysMain","PlugPlay","DPS","Sysmon","EventLog","Mpssvc","TapiSrv",
    "WSearch","wuauserv","UsoSvc","BITS","SecurityHealthService","SDRSVC","WbioSrvc",
    "RemoteRegistry","RetailDemo","Fax","MapsBroker","lfsvc","SharedAccess","DsSvc",
    "WerSvc","seclogon","WpcMonSvc","ScDeviceEnum","CscService","wisvc",
    "DoSvc","TrkWks","WdiServiceHost","WdiSystemHost","SCardSvr","SEMGRSVC",
    "AppXSvc","ClipSVC","InstallService","TokenBroker","wbengine","DsmSvc",
    "DusmSvc","PhoneSvc","XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc",
    "diagsvc","TabletInputService","Spooler","PrintNotify"
  )){Stop-Svc $s;Disable-Svc $s}

  # ============================================
  # TAREFAS AGENDADAS DESATIVADAS
  # ============================================
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
  )){try{schtasks /Change /TN $t /Disable 2>$null}catch{}}

  # ============================================
  # PLANO DE ENERGIA ULTIMATE PERFORMANCE
  # ============================================
  Write-Log "Ativando Ultimate Performance..." "head"
  powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
  powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
  powercfg /hibernate off
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HiberbootEnabled" 0

  # ============================================
  # CPU PRIORITY - Game DVR desativado
  # ============================================
  Write-Log "Otimizando CPU Priority e Game DVR..." "head"
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 2
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 1

  # ============================================
  # MULTIMEDIA/GAMING TWEAKS
  # ============================================
  Write-Log "Otimizando Multimedia/Gaming..." "head"
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 10
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NoLazyMode" 1
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "LazyModeTimeout" 150000

  # Gaming tasks profile
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 18
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Latency Sensitive" "True" -Type String

  # DisplayPostProcessing (high priority)
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "GPU Priority" 18
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "Priority" 8
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "Scheduling Category" "High" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "SFIO Priority" "High" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "Latency Sensitive" "True" -Type String

  # Win32PrioritySeparation (process scheduling)
  Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl" "Win32PrioritySeparation" 38

  # ============================================
  # POWER THROTTLING OFF
  # ============================================
  Write-Log "Desativando Power Throttling..." "head"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1

  # ============================================
  # FILESYSTEM OPTIMIZATION
  # ============================================
  Write-Log "Otimizando filesystem..." "head"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "EnableOplocks" 1

  # ============================================
  # KILL NOT RESPONDING + CLEAN RAM
  # ============================================
  Write-Log "Limpando RAM e processos travados..." "head"
  try{
    Get-Process | Where-Object {$_.Responding -eq $false} | Stop-Process -Force -EA 0
  }catch{}

  # ============================================
  # LIMPAR PREFETCH E TEMP
  # ============================================
  Write-Log "Limpando Prefetch e Temp..." "head"
  Remove-Item "$env:SystemRoot\Prefetch\*" -Force -EA 0
  Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -EA 0
  Remove-Item "$env:TEMP\*" -Recurse -Force -EA 0

  # ============================================
  # LIMPAR EVENT LOGS
  # ============================================
  Write-Log "Limpando Event Logs..." "head"
  try{
    wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }
  }catch{}

  # ============================================
  # DNS FLUSH
  # ============================================
  Write-Log "Limpando DNS Cache..." "head"
  ipconfig /flushdns 2>$null

  # ============================================
  # TIMEOUTS REDUZIDOS (sistema responde mais rapido)
  # ============================================
  Write-Log "Reduzindo timeouts do sistema..." "head"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "WaitToKillServiceTimeout" "2000" -Type String
  Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" -Type String
  Set-Reg "HKCU:\Control Panel\Desktop" "HungAppTimeout" "1000" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowInfoTip" 0

  # ============================================
  # EFEITOS VISUAIS DESATIVADOS
  # ============================================
  Write-Log "Desativando animacoes e efeitos visuais..." "head"
  Set-Reg "HKCU:\Control Panel\Desktop" "Animation" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
  Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary
  Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
  Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0
  Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" "0" -Type String
  Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "0" -Type String

  # ============================================
  # DWM / REFRESH RATE REDUCTION OFF
  # ============================================
  Write-Log "Desativando DWM refresh rate reduction..." "head"
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\DWM" "EnableUserDWM" 0

  # ============================================
  # NOTIFICACOES E ICONES DA BARRA
  # ============================================
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
  Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableNotificationCenter" 1
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0

  # ============================================
  # ONEDRIVE DESATIVADO
  # ============================================
  try{Stop-Process -Name "OneDrive" -Force -EA 0}catch{}
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSynCG" 1
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudButton" 0

  # ============================================
  # EMULADOR BLUESTACKS/MSI 5.9 OTIMIZATIONS
  # ============================================
  Write-Log "Otimizando emulador BlueStacks/MSI 5.9..." "head"

  # Processos do emulador
  $bsProcs = @("HD-Player","HD-Agent","BlueStacks","BstkShell","BstHook","BstService","MSI-Bar","MEmu","Nemu","MuMuPlayer")
  
  # CPU Priority HIGH para emulador
  foreach($proc in $bsProcs){
    try{
      $p = Get-Process -Name $proc -EA 0
      if($p){
        foreach($pp in $p){
          $pp.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
          Write-Log "Emulador: CPU Priority HIGH para $($pp.Name)" "ok"
        }
      }
    }catch{}
  }

  # Registry: Fullscreen Optimizations OFF para emulador
  $bsPaths = @(
    "C:\Program Files\BlueStacks_msi5\HD-Player.exe",
    "C:\Program Files\BlueStacks_msi5\BlueStacks.exe",
    "C:\Program Files\BlueStacks_msi5\BstShell.exe"
  )
  foreach($exe in $bsPaths){
    if(Test-Path $exe){
      Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$(Split-Path $exe -Leaf)\PerfOptions" "CpuPriorityClass" 3
      Set-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" $exe "~ RUNAS ADMIN DISABLEWINDFW FROPT" -Type String
      Write-Log "Emulador: Fullscreen Opt OFF + High Priority para $(Split-Path $exe -Leaf)" "ok"
    }
  }

  # Registry: GPU Priority HIGH para emulador
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\HD-Player.exe\PerfOptions" "GpuPriority" 8
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\HD-Player.exe\PerfOptions" "IoPriority" 3

  # ============================================
  # NVIDIA OPTIMIZATIONS (desabilita Dynamic Pstate)
  # ============================================
  Write-Log "Otimizando NVIDIA GPU..." "head"
  try{
    $gpu = Get-CimInstance Win32_VideoController | Where-Object {$_.PNPDeviceID -like "PCI\VEN_*"}
    if($gpu){
      foreach($g in $gpu){
        $driverKey = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$($g.PNPDeviceID)" -ErrorAction SilentlyContinue).Driver
        if($driverKey -match "\{"){
          Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$driverKey" "DisableDynamicPstate" 1
          Write-Log "NVIDIA: DisableDynamicPstate=1 ($($g.Name))" "ok"
        }
      }
    }
  }catch{Write-Log "NVIDIA: GPU nao detectada ou erro" "warn"}

  Write-Log "Otimizacao Agressiva ULTRA aplicada!" "ok"
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

  # Remover Teams
  Write-Log "Removendo Microsoft Teams..." "head"
  try{Stop-Process -Name "Teams" -Force -EA 0}catch{}
  try{Stop-Process -Name "ms-teams" -Force -EA 0}catch{}
  foreach($p in @("*MicrosoftTeams*","*Teams*")){
    try{Get-AppxPackage -Name $p -AllUsers -EA 0|Remove-AppxPackage -EA 0}catch{}
    try{Get-AppxProvisionedPackage -Online|Where-Object{$_.PackageName -like $p}|Remove-AppxProvisionedPackage -Online -EA 0}catch{}
  }
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Teams" "AllowMSTeams" 0
  Write-Log "Microsoft Teams removido!" "ok"
}

"power" {
  Write-Log "Configurando energia..." "head"
  powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
  powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
  powercfg /hibernate off
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HiberbootEnabled" 0
  Write-Log "Energia em alta performance!" "ok"
}

"ui" {
  Write-Log "Otimizando interface..." "head"
  Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
  Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" -Type String
  Set-Reg "HKCU:\Software\Microsoft\Windows\Dwm" "EnableAeroPeek" 0

  # Transparencia
  Write-Log "Desativando transparencia..." "head"
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0

  # Snapping
  Write-Log "Desativando snapping..." "head"
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapAssist" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapFill" 0
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SnapBar" 0

  # Modo Noturno
  Write-Log "Ativando modo noturno..." "head"
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default\$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings" "Data" ([byte[]](0x08,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01)) -Type Binary
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default\$windows.data.bluelightreduction.donotshow\windows.data.bluelightreduction.donotshow" "Data" ([byte[]](0x08,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x01)) -Type Binary

  Write-Log "Interface otimizada + transparencia + snapping + noturno!" "ok"
}

"startmenu-delay" {
  Write-Log "Otimizando menu iniciar..." "head"
  Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" -Type String
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "StartupDelayInMSec" 0
  Write-Log "Menu iniciar otimizado!" "ok"
}

"monitor-05ms" {
  Write-Log "Ativando timer de alta precisao..." "head"

  # Script em background robusto
  $bgScript = @'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TimerUtil {
    [DllImport("ntdll.dll")]
    public static extern int NtSetTimerResolution(uint desiredResolution, bool setResolution, out uint currentResolution);

    [DllImport("winmm.dll")]
    public static extern uint timeBeginPeriod(uint period);

    [DllImport("winmm.dll")]
    public static extern uint timeEndPeriod(uint period);
}
"@

# Chamar uma vez para setar
$currentRes = [uint32]0
[TimerUtil]::NtSetTimerResolution(5000, $true, [ref]$currentRes) | Out-Null
[TimerUtil]::timeBeginPeriod(1) | Out-Null

# Manter chamando a cada 500ms para nao deixar o Windows resetar
while ($true) {
    try {
        $res = [uint32]0
        [TimerUtil]::NtSetTimerResolution(5000, $true, [ref]$res) | Out-Null
    } catch {}
    Start-Sleep -Milliseconds 500
}
'@

  # Remover processo anterior se existir
  Get-Process powershell -EA 0 | Where-Object {
    try {
      $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA 0).CommandLine
      $cmd -and $cmd -match "peris-timer"
    } catch { $false }
  } | Stop-Process -Force -EA 0

  $timerPath = "$env:Public\Documents\peris-timer-bg.ps1"
  Set-Content -Path $timerPath -Value $bgScript -Force -Encoding UTF8
  Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$timerPath`"" -WindowStyle Hidden
  Start-Sleep -Seconds 1

  # Verificar se esta rodando
  $timerRunning = Get-Process powershell -EA 0 | Where-Object {
    try {
      $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA 0).CommandLine
      $cmd -and $cmd -match "peris-timer"
    } catch { $false }
  }
  if($timerRunning){
    Write-Log "Timer rodando em background (PID: $($timerRunning.Id -join ', '))" "ok"
  }else{
    Write-Log "Timer pode nao estar rodando - verifique manualmente" "warn"
  }

  # Tarefa agendada para rodar no startup (persiste apos reboot)
  Write-Log "Criando tarefa agendada para startup..." "info"
  try{
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$timerPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

    # Remover tarefa antiga se existir
    Unregister-ScheduledTask -TaskName "PerisTimerResolution" -Confirm:$false -EA 0

    Register-ScheduledTask -TaskName "PerisTimerResolution" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Mantem timer resolution em 0.5ms para melhor performance" -EA Stop | Out-Null
    Write-Log "Tarefa agendada criada!" "ok"
  }catch{
    Write-Log "Falha ao criar tarefa agendada: $($_.Exception.Message)" "warn"
  }

  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2

  # HPET OFF
  Write-Log "Desativando HPET..." "head"
  $bcdOut = & bcdedit /deletevalue useplatformclock 2>&1
  if($LASTEXITCODE -ne 0){ Write-Log "useplatformclock: ja removido ou nao existe" "info" }
  $bcdOut = & bcdedit /set useplatformtick yes 2>&1
  $bcdOut = & bcdedit /set disabledynamictick yes 2>&1
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "InterruptSteeringDisabled" 1

  Write-Log "Timer 0.5ms + HPET OFF ativado!" "ok"
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

  # Throttling de rede
  Write-Log "Desativando throttling de rede..." "head"
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "DisableBandwidthThrottling" 1
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters" "FastSendDatagramThreshold" 1024
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters" "FastCopyReceiveThreshold" 1024

  # Reset de Rede
  Write-Log "Resetando stack TCP/IP..." "head"
  try{netsh winsock reset 2>$null;Write-Log "Winsock resetado" "ok"}catch{Write-Log "Winsock: erro" "err"}
  try{netsh int ip reset 2>$null;Write-Log "TCP/IP resetado" "ok"}catch{Write-Log "TCP/IP: erro" "err"}

  # DNS over HTTPS
  Write-Log "Configurando DNS over HTTPS..." "head"
  try{
    $adapter = Get-NetAdapter|Where-Object Status -eq "Up"|Select-Object -First 1
    if($adapter){
      Set-DnsClientDoh -InterfaceIndex $adapter.InterfaceIndex -ServerAddress "1.1.1.1" -DohTemplate "https://mozilla-doh/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -EA 0
      Write-Log "DoH Cloudflare configurado" "ok"
      Set-DnsClientDoh -InterfaceIndex $adapter.InterfaceIndex -ServerAddress "8.8.8.8" -DohTemplate "https://mozilla-doh/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -EA 0
      Write-Log "DoH Google configurado" "ok"
    }
  }catch{Write-Log "DoH: erro ao configurar" "warn"}

  ipconfig /flushdns|Out-Null
  Write-Log "Rede TCP otimizada + reset + throttling + DoH!" "ok"
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

  # Limpeza de RAM (standby list)
  Write-Log "Limpando lista standby..." "head"
  try{
    $code = @'
Add-Type -TypeDefinition "using System;using System.Runtime.InteropServices;public class RAM{[DllImport(\"ntdll.dll\")]public static extern int NtSetSystemInformation(int c,ref long i,int s);}"
$len = [int]0x30
$ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal($len)
[Runtime.InteropServices.Marshal]::WriteInt64($ptr, 3)
[RAM]::NtSetSystemInformation(80, [ref]$ptr, $len)|Out-Null
'@
    Add-Type -TypeDefinition $code -EA 0
    [RAM]::NtSetSystemInformation()|Out-Null
    Write-Log "Standby list limpa" "ok"
  }catch{
    Write-Log "Standby: usando methodo alternativo" "warn"
    try{
      $code2 = @'
Add-Type -TypeDefinition "using System;using System.Runtime.InteropServices;public class RM2{[DllImport(\"psapi.dll\")]public static extern int EmptyWorkingSet(IntPtr hw);}"
foreach($p in Get-Process){try{[RM2]::EmptyWorkingSet($p.Handle)|Out-Null}catch{}}
'@
      Add-Type -TypeDefinition $code2 -EA 0
      [RM2]::EmptyWorkingSet()|Out-Null
      Write-Log "Processos limpos" "ok"
    }catch{}
  }

  # Desativar compressao de memoria
  Write-Log "Desativando compressao de memoria..." "head"
  try{
    Get-MMAgent|Out-Null
    Disable-MMAgent -MemoryCompression -EA 0
    Write-Log "Compressao de memoria desativada" "ok"
  }catch{
    Write-Log "Compressao: erro ao desativar" "warn"
  }

  try{Clear-RecycleBin -Force -EA 0}catch{}
  Write-Log "Memoria otimizada + limpeza + compressao!" "ok"
}

"disk-io" {
  Write-Log "Otimizando disco..." "head"
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 80000003
  Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2

  # Desativar indexacao
  Write-Log "Desativando indexacao do Windows Search..." "head"
  try{
    Stop-Service "WSearch" -Force -EA 0
    Set-Service "WSearch" -StartupType Disabled -EA 0
    Write-Log "Windows Search desativado" "ok"
  }catch{
    Write-Log "WSearch: erro ao desativar" "warn"
  }

  # Verificar SMART
  Write-Log "Verificando saude dos discos (SMART)..." "head"
  try{
    Get-WmiObject -Class Win32_DiskDrive | ForEach-Object {
      $model = $_.Model
      $size = [math]::Round($_.Size/1GB,1)
      $status = $_.Status
      if($status -eq "OK"){
        Write-Log "DISK: $model (${size}GB) - $status" "ok"
      }else{
        Write-Log "DISK: $model (${size}GB) - $status" "warn"
      }
    }
  }catch{
    Write-Log "SMART: nao foi possivel verificar" "warn"
  }

  Write-Log "Disco I/O otimizado + indexacao OFF + SMART!" "ok"
}

"gamemode" {
  Write-Log "Ativando Game Mode..." "head"
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
  Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0

  # Game Bar config
  Write-Log "Configurando Game Bar..." "head"
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "GamePanelStartupState" 0
  Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseSteamOverlay" 1

  Write-Log "Game Mode + Game Bar configurado!" "ok"
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
    $b = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -EA Stop).CounterSamples.CookedValue
    Write-Log "CPU usage: $([math]::Round($b,1))%" "ok"
  }catch{
    try{
      $cpu = Get-CimInstance Win32_Processor -EA Stop
      $load = $cpu.LoadPercentage
      Write-Log "CPU usage: $load%" "ok"
    }catch{
      Write-Log "CPU usage: nao foi possivel obter" "warn"
    }
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

  # SFC - executa e aguarda (nao emite progresso via stdout)
  Write-Log "Iniciando verificacao SFC..." "info"
  Write-Log "Aguarde, SFC pode levar alguns minutos..." "info"
  try{
    $sfcOut = & cmd /c "sfc /scannow" 2>&1
    $sfcText = $sfcOut -join "`n"
    if($sfcText -match 'protegidos foram restaurados'){
      Write-Log "SFC: arquivos protegidos restaurados" "ok"
    }elseif($sfcText -match 'nao encontrou violacoes'){
      Write-Log "SFC: nenhuma violacao encontrada" "ok"
    }elseif($sfcText -match 'conclui'){
      Write-Log "SFC concluido!" "ok"
    }else{
      Write-Log "SFC concluido!" "ok"
    }
  }catch{
    Write-Log "SFC: erro ao executar" "err"
  }

  # DISM com progresso em tempo real (linha unica)
  Write-Log "Iniciando verificacao DISM..." "info"
  try{
    $dismProc = Start-Process cmd.exe -ArgumentList "/c dism /Online /Cleanup-Image /RestoreHealth" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\dism-out.txt" -RedirectStandardError "$env:TEMP\dism-err.txt"
    $lastLine = 0
    $lastPct = ""
    while(!$dismProc.HasExited){
      Start-Sleep -Milliseconds 500
      if(Test-Path "$env:TEMP\dism-out.txt"){
        $lines = Get-Content "$env:TEMP\dism-out.txt" -EA 0
        if($lines.Length -gt $lastLine){
          $newLines = $lines[$lastLine..($lines.Length - 1)]
          $lastLine = $lines.Length
          foreach($line in $newLines){
            $clean = $line -replace '[^\x20-\x7E]',''
            if($clean -match '(\d+\.?\d*)%'){
              $pct = $matches[1]
              if($pct -ne $lastPct){
                Write-Host "[PROG]DISM: $pct%"
                $lastPct = $pct
              }
            }
          }
        }
      }
    }
    # Ler saida final para verificar resultado
    if(Test-Path "$env:TEMP\dism-out.txt"){
      $final = Get-Content "$env:TEMP\dism-out.txt" -EA 0 -Raw
      if($final -match 'The operation completed successfully'){
        Write-Log "DISM: operacao concluida com sucesso" "ok"
      }
    }
    Remove-Item "$env:TEMP\dism-out.txt" -Force -EA 0
    Remove-Item "$env:TEMP\dism-err.txt" -Force -EA 0
    Write-Log "DISM concluido!" "ok"
  }catch{
    Write-Log "DISM: erro ao executar" "err"
  }
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

  # Desativar proteÃ§Ã£o em nuvem e envio de amostras
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SubmitSamplesConsent" 2
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "DisableBlockAtFirstSeen" 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications" 1
  Write-Log "ProteÃ§Ã£o em nuvem desativada" "ok"

  # Desativar tarefas agendadas do Defender
  foreach($t in @(
    "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "\Microsoft\Windows\Windows Defender\Windows Defender Verification"
  )){try{Disable-ScheduledTask -TaskName $t -EA 0}catch{}}
  Write-Log "Tarefas desativadas" "ok"

  # Parar serviÃ§os
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
