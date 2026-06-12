$r = @{}
try { $os = Get-CimInstance Win32_OperatingSystem; $r.os = $os.Caption } catch {}
try { $c = Get-CimInstance Win32_Processor; $r.cpu = $c.Name; $r.cores = $c.NumberOfCores; $r.threads = $c.NumberOfLogicalProcessors; $r.arch = $c.Architecture; $r.socket = $c.SocketDesignation; $r.tdp = [math]::Round($c.MaxClockSpeed/1000,1) } catch {}
try { $g = Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike '*Basic*'} | Select-Object -First 1; $r.gpu = $g.Name; $r.driver = $g.DriverVersion; $r.res = "$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution)"; $r.hz = "$($g.CurrentRefreshRate) Hz" } catch {}
try { $m = Get-CimInstance WmiMonitorID -Namespace root\wmi -EA 0 | Select -First 1; if($m){$n=($m.UserFriendlyName|Where-Object{$_ -ne 0}|ForEach-Object{[char]$_}) -join ''; $r.mon=$n}else{$r.mon=""} } catch {}
try { $r.ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB) } catch {}
try { $mb = Get-CimInstance Win32_BaseBoard; $r.mb = $mb.Product; $r.mfr = $mb.Manufacturer } catch {}
try { $r.bios = (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion } catch {}
try { $disks = @(); Get-Volume | Where-Object { $_.Size -gt 0 -and $_.DriveLetter } | ForEach-Object { $disks += @{ letter = $_.DriveLetter; label = $_.FileSystemLabel; sizeGB = [math]::Round($_.Size/1GB,0); freeGB = [math]::Round($_.SizeRemaining/1GB,0) } }; $r.disks = $disks } catch {}
$r | ConvertTo-Json -Compress
