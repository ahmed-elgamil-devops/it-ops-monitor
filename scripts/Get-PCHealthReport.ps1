<#
.SYNOPSIS
  Quick health report for a Windows PC - the first thing a help desk checks.
.EXAMPLE
  .\Get-PCHealthReport.ps1 -OutFile report.html
#>
param([string]$OutFile = "$env:COMPUTERNAME-health.html")

$os   = Get-CimInstance Win32_OperatingSystem
$cpu  = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    [pscustomobject]@{
        Drive     = $_.DeviceID
        SizeGB    = [math]::Round($_.Size / 1GB, 1)
        FreeGB    = [math]::Round($_.FreeSpace / 1GB, 1)
        FreePct   = [math]::Round($_.FreeSpace / $_.Size * 100)
    }
}
$uptime   = (Get-Date) - $os.LastBootUpTime
$ramUsed  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100)
$pending  = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
$services = Get-Service -Name Spooler, wuauserv, WinDefend -ErrorAction SilentlyContinue |
            Select-Object Name, Status

$summary = [pscustomobject]@{
    Computer        = $env:COMPUTERNAME
    User            = $env:USERNAME
    OS              = $os.Caption
    UptimeDays      = [math]::Round($uptime.TotalDays, 1)
    CpuLoadPct      = $cpu
    RamUsedPct      = $ramUsed
    LastUpdateDate  = $pending
}

$html = @(
    "<h1>PC Health Report - $env:COMPUTERNAME</h1>"
    ($summary | ConvertTo-Html -As List -Fragment)
    "<h2>Disks</h2>"; ($disk | ConvertTo-Html -Fragment)
    "<h2>Key services</h2>"; ($services | ConvertTo-Html -Fragment)
) -join "`n"

ConvertTo-Html -Body $html -Title "PC Health" | Out-File $OutFile -Encoding utf8
Write-Host "Report saved to $OutFile"
if ($disk | Where-Object FreePct -lt 15) { Write-Warning "Low disk space on at least one drive" }
