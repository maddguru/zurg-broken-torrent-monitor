# ============================================================================
# Zurg Broken Torrent Monitor & Repair Tool v2.0
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ZurgUrl = "http://localhost:9999",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "riven",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "12345",
    
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalMinutes = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "zurg-broken-torrent-monitor.log",
    
    [Parameter(Mandatory=$false)]
    [switch]$RunOnce,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging
)

$ErrorActionPreference = "Continue"
$Script:Stats = @{
    TotalChecks = 0
    BrokenFound = 0
    RepairsTriggered = 0
    LastCheck = $null
    LastBrokenFound = $null
    CurrentCheck = @{
        BrokenFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
    }
    PreviousCheck = @{
        BrokenHashes = @()
        TriggeredHashes = @()
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        "WARN"    { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG"   { if ($VerboseLogging) { Write-Host $logMessage -ForegroundColor Gray } }
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-Banner {
    param([string]$Text)
    
    $line = "=" * 72
    
    Write-Host ""
    Write-Host $line -ForegroundColor Magenta
    Write-Host "  $Text" -ForegroundColor Magenta
    Write-Host $line -ForegroundColor Magenta
    Write-Host ""
    
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value $line
    Add-Content -Path $LogFile -Value "  $Text"
    Add-Content -Path $LogFile -Value $line
    Add-Content -Path $LogFile -Value ""
}

function Get-AuthHeaders {
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    if ($Username -and $Password) {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
        $headers["Authorization"] = "Basic $base64AuthInfo"
    }
    
    return $headers
}

function Test-ZurgConnection {
    try {
        Write-Log "Testing connection to Zurg at $ZurgUrl..." "DEBUG"
        $headers = Get-AuthHeaders
        $response = Invoke-RestMethod -Uri "$ZurgUrl/stats" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Log "Successfully connected to Zurg" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to connect to Zurg: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-ZurgBrokenTorrents {
    try {
        Write-Log "Fetching broken torrents from Zurg (using state filter)..." "DEBUG"
        $headers = Get-AuthHeaders
        
        $url = "$ZurgUrl/manage/?state=status_broken"
        Write-Log "Fetching: $url" "DEBUG"
        
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 30 -ErrorAction Stop -UseBasicParsing
            $content = $response.Content
            
            Write-Log "Successfully fetched broken torrents page (length: $($content.Length) bytes)" "DEBUG"
        }
        catch {
            Write-Log "Failed to fetch broken torrents page: $($_.Exception.Message)" "ERROR"
            return $null
        }
        
        $torrents = @()
        $processedHashes = @{}
        
        # Look for table rows with torrent data
        $rowPattern = '<tr[^>]*data-hash="([a-fA-F0-9]{40})"[^>]*>'
        $rowMatches = [regex]::Matches($content, $rowPattern)
        
        Write-Log "Found $($rowMatches.Count) torrent row(s) in broken torrents page" "DEBUG"
        
        if ($rowMatches.Count -eq 0) {
            # Fallback: Look for manage links
            Write-Log "No data-hash attributes found, trying fallback pattern..." "DEBUG"
            $hashPattern = 'href="/manage/([a-fA-F0-9]{40})/"'
            $hashMatches = [regex]::Matches($content, $hashPattern)
            Write-Log "Fallback: Found $($hashMatches.Count) manage link(s)" "DEBUG"
            
            foreach ($match in $hashMatches) {
                $hash = $match.Groups[1].Value.ToLower()
                
                if ($processedHashes.ContainsKey($hash)) {
                    continue
                }
                $processedHashes[$hash] = $true
                
                $contextStart = [Math]::Max(0, $match.Index - 1000)
                $contextEnd = [Math]::Min($content.Length, $match.Index + 1000)
                $context = $content.Substring($contextStart, $contextEnd - $contextStart)
                
                $torrentName = "Unknown ($hash)"
                
                # Pattern 1: Link text
                $namePattern1 = 'href="/manage/' + $hash + '/">([^<]+)</a>'
                $nameMatch1 = [regex]::Match($context, $namePattern1)
                if ($nameMatch1.Success) {
                    $torrentName = [System.Web.HttpUtility]::HtmlDecode($nameMatch1.Groups[1].Value.Trim())
                }
                else {
                    # Pattern 2: data-name attribute
                    $namePattern2 = 'data-name="([^"]+)"'
                    $nameMatch2 = [regex]::Match($context, $namePattern2)
                    if ($nameMatch2.Success) {
                        $torrentName = [System.Web.HttpUtility]::HtmlDecode($nameMatch2.Groups[1].Value.Trim())
                    }
                }
                
                Write-Log "  Found broken torrent: $torrentName" "DEBUG"
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = "broken_torrent"
                }
            }
        }
        else {
            # Process rows with data-hash
            foreach ($match in $rowMatches) {
                $hash = $match.Groups[1].Value.ToLower()
                
                if ($processedHashes.ContainsKey($hash)) {
                    continue
                }
                $processedHashes[$hash] = $true
                
                $rowStart = $match.Index
                $rowEnd = $content.IndexOf('</tr>', $rowStart)
                if ($rowEnd -eq -1) { $rowEnd = [Math]::Min($content.Length, $rowStart + 2000) }
                $rowContent = $content.Substring($rowStart, $rowEnd - $rowStart)
                
                $torrentName = "Unknown ($hash)"
                
                # Pattern 1: Link to manage page
                $namePattern1 = 'href="/manage/' + $hash + '/">([^<]+)</a>'
                $nameMatch1 = [regex]::Match($rowContent, $namePattern1)
                if ($nameMatch1.Success) {
                    $torrentName = [System.Web.HttpUtility]::HtmlDecode($nameMatch1.Groups[1].Value.Trim())
                }
                else {
                    # Pattern 2: data-name attribute
                    $namePattern2 = 'data-name="([^"]+)"'
                    $nameMatch2 = [regex]::Match($rowContent, $namePattern2)
                    if ($nameMatch2.Success) {
                        $torrentName = [System.Web.HttpUtility]::HtmlDecode($nameMatch2.Groups[1].Value.Trim())
                    }
                    else {
                        # Pattern 3: First <a> tag in the row
                        $namePattern3 = '<a[^>]+>([^<]+)</a>'
                        $nameMatch3 = [regex]::Match($rowContent, $namePattern3)
                        if ($nameMatch3.Success) {
                            $possibleName = [System.Web.HttpUtility]::HtmlDecode($nameMatch3.Groups[1].Value.Trim())
                            if ($possibleName -notmatch '^\d+\.\d+\s*(GB|MB|KB|TB)$' -and $possibleName.Length -gt 5) {
                                $torrentName = $possibleName
                            }
                        }
                    }
                }
                
                Write-Log "  Found broken torrent: $torrentName" "DEBUG"
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = "broken_torrent"
                }
            }
        }
        
        Write-Log "Successfully parsed $($torrents.Count) broken torrent(s)" "DEBUG"
        return $torrents
    }
    catch {
        Write-Log "Error getting broken torrents: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

function Invoke-TorrentRepair {
    param(
        [string]$Hash,
        [string]$Name
    )
    
    try {
        Write-Log "Triggering repair for torrent: $Name" "INFO"
        $headers = Get-AuthHeaders
        
        $repairUrl = "$ZurgUrl/manage/$Hash/repair"
        Write-Log "  Repair URL: $repairUrl" "DEBUG"
        
        try {
            $response = Invoke-RestMethod -Uri $repairUrl -Method Post -Headers $headers -TimeoutSec 30 -ErrorAction Stop
            Write-Log "Successfully triggered repair for: $Name" "SUCCESS"
            return $true
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }
            
            Write-Log "Failed to trigger repair for '$Name': $($_.Exception.Message) (Status: $statusCode)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error triggering repair for '$Name': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Start-BrokenTorrentCheck {
    Write-Log "" "INFO"
    Write-Log "Starting broken torrent check..." "INFO"
    
    $Script:Stats.CurrentCheck = @{
        BrokenFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
    }
    
    $brokenTorrents = Get-ZurgBrokenTorrents
    
    if ($null -eq $brokenTorrents) {
        Write-Log "Failed to retrieve broken torrents" "ERROR"
        $Script:Stats.TotalChecks++
        $Script:Stats.LastCheck = Get-Date
        return
    }
    
    $Script:Stats.TotalChecks++
    $Script:Stats.LastCheck = Get-Date
    
    Write-Log "Found $($brokenTorrents.Count) broken torrent(s) (matching Zurg web interface)" "INFO"
    
    if ($brokenTorrents.Count -eq 0) {
        Write-Log "No broken torrents found - all good!" "SUCCESS"
        Write-Log "Broken torrent check completed" "INFO"
        Show-CheckSummary
        return
    }
    
    $Script:Stats.CurrentCheck.BrokenFound = $brokenTorrents.Count
    $Script:Stats.BrokenFound += $brokenTorrents.Count
    $Script:Stats.LastBrokenFound = Get-Date
    
    foreach ($torrent in $brokenTorrents) {
        Write-Log "  Found broken torrent: $($torrent.Name)" "WARN"
        $Script:Stats.CurrentCheck.BrokenHashes += $torrent.Hash
        $Script:Stats.CurrentCheck.BrokenNames += $torrent.Name
    }
    
    Write-Log "" "INFO"
    Write-Log "Triggering repairs..." "INFO"
    
    foreach ($torrent in $brokenTorrents) {
        $success = Invoke-TorrentRepair -Hash $torrent.Hash -Name $torrent.Name
        
        if ($success) {
            $Script:Stats.CurrentCheck.RepairsTriggered++
            $Script:Stats.RepairsTriggered++
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Log "" "INFO"
    Write-Log "Broken torrent check completed" "INFO"
    
    Show-CheckSummary
    
    $Script:Stats.PreviousCheck.BrokenHashes = $Script:Stats.CurrentCheck.BrokenHashes
    $Script:Stats.PreviousCheck.TriggeredHashes = $Script:Stats.CurrentCheck.BrokenHashes
}

function Show-Statistics {
    Write-Banner "OVERALL STATISTICS"
    
    $lastCheck = if ($Script:Stats.LastCheck) { $Script:Stats.LastCheck.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    $lastBroken = if ($Script:Stats.LastBrokenFound) { $Script:Stats.LastBrokenFound.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    
    Write-Host "Total Checks Performed:    $($Script:Stats.TotalChecks)" -ForegroundColor Cyan
    Write-Host "Total Broken Found:        $($Script:Stats.BrokenFound)" -ForegroundColor Cyan
    Write-Host "Total Repairs Triggered:   $($Script:Stats.RepairsTriggered)" -ForegroundColor Cyan
    Write-Host "Last Check:                $lastCheck" -ForegroundColor Cyan
    Write-Host "Last Broken Found:         $lastBroken" -ForegroundColor Cyan
}

function Show-CheckSummary {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  CHECK SUMMARY" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CURRENT CHECK RESULTS:" -ForegroundColor Yellow
    Write-Host "  Broken Torrents Found:     $($Script:Stats.CurrentCheck.BrokenFound)" -ForegroundColor Yellow
    Write-Host "  Repairs Triggered:         $($Script:Stats.CurrentCheck.RepairsTriggered)" -ForegroundColor Green
    
    if ($Script:Stats.CurrentCheck.BrokenNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Broken Torrents:" -ForegroundColor Yellow
        foreach ($name in $Script:Stats.CurrentCheck.BrokenNames) {
            Write-Host "    - $name" -ForegroundColor Yellow
        }
    }
    
    # Comparison with previous check (if exists)
    if ($Script:Stats.PreviousCheck.BrokenHashes.Count -gt 0) {
        Write-Host ""
        Write-Host "COMPARISON WITH PREVIOUS CHECK:" -ForegroundColor Cyan
        
        # Calculate what was repaired (was broken, now not)
        $repairedCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.TriggeredHashes) {
            if ($Script:Stats.CurrentCheck.BrokenHashes -notcontains $hash) {
                $repairedCount++
            }
        }
        
        # Calculate what's still broken from previous
        $stillBrokenCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.TriggeredHashes) {
            if ($Script:Stats.CurrentCheck.BrokenHashes -contains $hash) {
                $stillBrokenCount++
            }
        }
        
        # Calculate new broken (not in previous check)
        $newBrokenCount = 0
        foreach ($hash in $Script:Stats.CurrentCheck.BrokenHashes) {
            if ($Script:Stats.PreviousCheck.BrokenHashes -notcontains $hash) {
                $newBrokenCount++
            }
        }
        
        Write-Host "  Successfully Repaired:     $repairedCount" -ForegroundColor $(if ($repairedCount -gt 0) { "Green" } else { "Gray" })
        Write-Host "  Still Broken (from prev):  $stillBrokenCount" -ForegroundColor $(if ($stillBrokenCount -gt 0) { "Yellow" } else { "Green" })
        Write-Host "  New Broken (not in prev):  $newBrokenCount" -ForegroundColor $(if ($newBrokenCount -gt 0) { "Yellow" } else { "Green" })
        
        # Calculate success rate
        if ($Script:Stats.PreviousCheck.TriggeredHashes.Count -gt 0) {
            $successRate = [math]::Round(($repairedCount / $Script:Stats.PreviousCheck.TriggeredHashes.Count) * 100, 1)
            Write-Host "  Repair Success Rate:       $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
        }
    }
    
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Start-MonitoringLoop {
    Write-Banner "ZURG BROKEN TORRENT MONITOR v2.0"
    
    Write-Log "Starting Zurg Broken Torrent Monitor" "INFO"
    Write-Log "Zurg URL: $ZurgUrl" "INFO"
    Write-Log "Check Interval: $CheckIntervalMinutes minutes" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    Write-Log "Authentication: $(if ($Username) { 'Enabled' } else { 'Disabled' })" "INFO"
    Write-Log "" "INFO"
    
    if (-not (Test-ZurgConnection)) {
        Write-Log "Cannot connect to Zurg - exiting" "ERROR"
        return
    }
    
    Write-Log "" "INFO"
    
    if ($RunOnce) {
        Write-Log "Running in single-check mode" "INFO"
        Start-BrokenTorrentCheck
        Write-Log "" "INFO"
        Show-Statistics
        return
    }
    
    Write-Log "Starting continuous monitoring loop (press Ctrl+C to stop)" "INFO"
    Write-Log "" "INFO"
    
    try {
        while ($true) {
            Start-BrokenTorrentCheck
            
            Write-Log "" "INFO"
            Write-Log "Next check in $CheckIntervalMinutes minutes..." "INFO"
            Write-Log "======================================================================" "INFO"
            Write-Log "" "INFO"
            
            Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
        }
    }
    catch {
        Write-Log "Monitoring loop interrupted: $($_.Exception.Message)" "WARN"
    }
    finally {
        Write-Log "" "INFO"
        Show-Statistics
        Write-Log "Monitoring stopped" "INFO"
    }
}

if ($CheckIntervalMinutes -lt 1) {
    Write-Host "Error: CheckIntervalMinutes must be at least 1" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
}

Add-Type -AssemblyName System.Web

Start-MonitoringLoop
