$r = @{}
try { $t = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/wmi -EA 0; $r.ct = [math]::Round(($t[0].CurrentTemperature-2732)/10) } catch {}
try { $n = nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,fan.speed,memory.used,memory.total --format=csv,noheader,nounits 2>$null; if($n){$p=$n -split ',';$r.gt=$p[0].Trim();$r.gu=$p[1].Trim();$r.gf=$p[2].Trim();$r.vu=$p[3].Trim();$r.vt=$p[4].Trim()}} catch {}
try { $cs=Get-CimInstance Win32_ComputerSystem; $os=Get-CimInstance Win32_OperatingSystem; $r.ramT=[math]::Round($cs.TotalPhysicalMemory/1GB,1); $r.ramU=[math]::Round($os.TotalVisibleMemorySize/1MB-$os.FreePhysicalMemory/1MB,1) } catch {}
$r | ConvertTo-Json -Compress
