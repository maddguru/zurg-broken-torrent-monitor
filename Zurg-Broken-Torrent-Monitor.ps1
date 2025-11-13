# ============================================================================
# Zurg Broken Torrent Monitor & Repair Tool v2.2.1
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
    UnderRepairFound = 0
    RepairsTriggered = 0
    LastCheck = $null
    LastBrokenFound = $null
    CurrentCheck = @{
        BrokenFound = 0
        UnderRepairFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
        UnderRepairHashes = @()
        UnderRepairNames = @()
        TotalTorrents = 0
        OkTorrents = 0
    }
    PreviousCheck = @{
        BrokenHashes = @()
        UnderRepairHashes = @()
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

function Get-ZurgTorrentsByState {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("status_broken", "status_under_repair")]
        [string]$State
    )
    
    try {
        $stateName = if ($State -eq "status_broken") { "broken" } else { "under repair" }
        Write-Log "Fetching $stateName torrents from Zurg..." "DEBUG"
        $headers = Get-AuthHeaders
        
        $url = "$ZurgUrl/manage/?state=$State"
        Write-Log "Fetching: $url" "DEBUG"
        
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 30 -ErrorAction Stop -UseBasicParsing
            $content = $response.Content
            
            Write-Log "Successfully fetched $stateName torrents page (length: $($content.Length) bytes)" "DEBUG"
        }
        catch {
            Write-Log "Failed to fetch $stateName torrents page: $($_.Exception.Message)" "ERROR"
            return $null
        }
        
        $torrents = @()
        $processedHashes = @{}
        
        # Look for table rows with torrent data
        $rowPattern = '<tr[^>]*data-hash="([a-fA-F0-9]{40})"[^>]*>'
        $rowMatches = [regex]::Matches($content, $rowPattern)
        
        Write-Log "Found $($rowMatches.Count) torrent row(s) in $stateName torrents page" "DEBUG"
        
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
                
                Write-Log "  Found $stateName torrent: $torrentName" "DEBUG"
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = $State
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
                
                Write-Log "  Found $stateName torrent: $torrentName" "DEBUG"
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = $State
                }
            }
        }
        
        Write-Log "Successfully parsed $($torrents.Count) $stateName torrent(s)" "DEBUG"
        return ,$torrents
    }
    catch {
        Write-Log "Error getting $stateName torrents: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

function Get-ZurgTotalTorrentStats {
    try {
        Write-Log "Fetching total torrent statistics..." "DEBUG"
        $headers = Get-AuthHeaders
        
        $url = "$ZurgUrl/manage/"
        Write-Log "Fetching: $url" "DEBUG"
        
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 30 -ErrorAction Stop -UseBasicParsing
            $content = $response.Content
            
            Write-Log "Successfully fetched torrents page (length: $($content.Length) bytes)" "DEBUG"
        }
        catch {
            Write-Log "Failed to fetch torrents page: $($_.Exception.Message)" "ERROR"
            return $null
        }
        
        # Count total torrents by finding all unique data-hash attributes
        $hashPattern = 'data-hash="([a-fA-F0-9]{40})"'
        $hashMatches = [regex]::Matches($content, $hashPattern)
        
        # Use a hashtable to get unique hashes
        $uniqueHashes = @{}
        foreach ($match in $hashMatches) {
            $hash = $match.Groups[1].Value.ToLower()
            $uniqueHashes[$hash] = $true
        }
        
        $totalTorrents = $uniqueHashes.Count
        Write-Log "Found $totalTorrents total torrent(s)" "DEBUG"
        
        return @{
            TotalTorrents = $totalTorrents
        }
    }
    catch {
        Write-Log "Error getting total torrent stats: $($_.Exception.Message)" "ERROR"
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
    Write-Log "Starting torrent status check..." "INFO"
    
    $Script:Stats.CurrentCheck = @{
        BrokenFound = 0
        UnderRepairFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
        UnderRepairHashes = @()
        UnderRepairNames = @()
        TotalTorrents = 0
        OkTorrents = 0
    }
    
    # Get total torrent statistics
    $totalStats = Get-ZurgTotalTorrentStats
    if ($null -ne $totalStats) {
        $Script:Stats.CurrentCheck.TotalTorrents = $totalStats.TotalTorrents
    }
    
    # Get broken torrents
    $brokenTorrents = Get-ZurgTorrentsByState -State "status_broken"
    
    # Get under repair torrents
    $underRepairTorrents = Get-ZurgTorrentsByState -State "status_under_repair"
    
    # Check for API failures (null means the API call failed, not that there are no torrents)
    $brokenApiSuccess = ($brokenTorrents -is [Array])
    $underRepairApiSuccess = ($underRepairTorrents -is [Array])
    
    # If BOTH API calls failed, that's an error
    if (-not $brokenApiSuccess -and -not $underRepairApiSuccess) {
        Write-Log "Failed to retrieve torrent status - API calls failed" "ERROR"
        $Script:Stats.TotalChecks++
        $Script:Stats.LastCheck = Get-Date
        return
    }
    
    # If one API call failed but the other succeeded, log a warning but continue
    if (-not $brokenApiSuccess) {
        Write-Log "Warning: Failed to fetch broken torrents, but continuing with under repair check" "WARN"
        $brokenTorrents = @()  # Treat as empty array to continue
    }
    
    if (-not $underRepairApiSuccess) {
        Write-Log "Warning: Failed to fetch under repair torrents, but continuing with broken check" "WARN"
        $underRepairTorrents = @()  # Treat as empty array to continue
    }
    
    $Script:Stats.TotalChecks++
    $Script:Stats.LastCheck = Get-Date
    
    # Process broken torrents
    if ($null -ne $brokenTorrents) {
        $Script:Stats.CurrentCheck.BrokenFound = $brokenTorrents.Count
        $Script:Stats.BrokenFound += $brokenTorrents.Count
        
        if ($brokenTorrents.Count -gt 0) {
            $Script:Stats.LastBrokenFound = Get-Date
        }
    }
    
    # Process under repair torrents
    if ($null -ne $underRepairTorrents) {
        $Script:Stats.CurrentCheck.UnderRepairFound = $underRepairTorrents.Count
        $Script:Stats.UnderRepairFound += $underRepairTorrents.Count
    }
    
    # Calculate OK torrents
    if ($Script:Stats.CurrentCheck.TotalTorrents -gt 0) {
        $Script:Stats.CurrentCheck.OkTorrents = $Script:Stats.CurrentCheck.TotalTorrents - 
                                                 $Script:Stats.CurrentCheck.BrokenFound - 
                                                 $Script:Stats.CurrentCheck.UnderRepairFound
    }
    
    Write-Log "Found $($Script:Stats.CurrentCheck.BrokenFound) broken torrent(s)" "INFO"
    Write-Log "Found $($Script:Stats.CurrentCheck.UnderRepairFound) under repair torrent(s)" "INFO"
    
    # Display broken torrents
    if ($null -ne $brokenTorrents -and $brokenTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "BROKEN TORRENTS:" "WARN"
        foreach ($torrent in $brokenTorrents) {
            Write-Log "  - $($torrent.Name)" "WARN"
            $Script:Stats.CurrentCheck.BrokenHashes += $torrent.Hash
            $Script:Stats.CurrentCheck.BrokenNames += $torrent.Name
        }
    }
    
    # Display under repair torrents
    if ($null -ne $underRepairTorrents -and $underRepairTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "UNDER REPAIR:" "INFO"
        foreach ($torrent in $underRepairTorrents) {
            Write-Log "  - $($torrent.Name)" "INFO"
            $Script:Stats.CurrentCheck.UnderRepairHashes += $torrent.Hash
            $Script:Stats.CurrentCheck.UnderRepairNames += $torrent.Name
        }
    }
    
    # Check if there's anything to repair
    if (($null -eq $brokenTorrents -or $brokenTorrents.Count -eq 0) -and 
        ($null -eq $underRepairTorrents -or $underRepairTorrents.Count -eq 0)) {
        Write-Log "" "SUCCESS"
        Write-Log "✓ No broken or under repair torrents found - library is healthy!" "SUCCESS"
        Write-Log "Torrent status check completed" "INFO"
        Show-CheckSummary
        
        # Save current as previous for next check (even with no issues)
        $Script:Stats.PreviousCheck.BrokenHashes = $Script:Stats.CurrentCheck.BrokenHashes
        $Script:Stats.PreviousCheck.UnderRepairHashes = $Script:Stats.CurrentCheck.UnderRepairHashes
        $Script:Stats.PreviousCheck.TriggeredHashes = @()
        return
    }
    
    Write-Log "" "INFO"
    Write-Log "Triggering repairs..." "INFO"
    
    # Trigger repair for broken torrents
    if ($null -ne $brokenTorrents -and $brokenTorrents.Count -gt 0) {
        foreach ($torrent in $brokenTorrents) {
            $success = Invoke-TorrentRepair -Hash $torrent.Hash -Name $torrent.Name
            
            if ($success) {
                $Script:Stats.CurrentCheck.RepairsTriggered++
                $Script:Stats.RepairsTriggered++
            }
            
            Start-Sleep -Milliseconds 500
        }
    }
    
    # Trigger repair for under repair torrents (re-trigger to help them along)
    if ($null -ne $underRepairTorrents -and $underRepairTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "Re-triggering repairs for under repair torrents..." "INFO"
        foreach ($torrent in $underRepairTorrents) {
            $success = Invoke-TorrentRepair -Hash $torrent.Hash -Name $torrent.Name
            
            if ($success) {
                $Script:Stats.CurrentCheck.RepairsTriggered++
                $Script:Stats.RepairsTriggered++
            }
            
            Start-Sleep -Milliseconds 500
        }
    }
    
    Write-Log "" "INFO"
    Write-Log "Torrent status check completed" "INFO"
    
    Show-CheckSummary
    
    # Save current as previous for next check
    $Script:Stats.PreviousCheck.BrokenHashes = $Script:Stats.CurrentCheck.BrokenHashes
    $Script:Stats.PreviousCheck.UnderRepairHashes = $Script:Stats.CurrentCheck.UnderRepairHashes
    # Combined list of all hashes that had repairs triggered
    $Script:Stats.PreviousCheck.TriggeredHashes = $Script:Stats.CurrentCheck.BrokenHashes + $Script:Stats.CurrentCheck.UnderRepairHashes
}

function Show-Statistics {
    Write-Banner "OVERALL STATISTICS"
    
    $lastCheck = if ($Script:Stats.LastCheck) { $Script:Stats.LastCheck.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    $lastBroken = if ($Script:Stats.LastBrokenFound) { $Script:Stats.LastBrokenFound.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    
    Write-Host "Total Checks Performed:    $($Script:Stats.TotalChecks)" -ForegroundColor Cyan
    Write-Host "Total Broken Found:        $($Script:Stats.BrokenFound)" -ForegroundColor Cyan
    Write-Host "Total Under Repair Found:  $($Script:Stats.UnderRepairFound)" -ForegroundColor Cyan
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
    
    # Display total torrent statistics if available
    if ($Script:Stats.CurrentCheck.TotalTorrents -gt 0) {
        Write-Host "TORRENT STATISTICS:" -ForegroundColor Magenta
        Write-Host "  Total Torrents:            $($Script:Stats.CurrentCheck.TotalTorrents)" -ForegroundColor White
        
        # Calculate percentages
        $okPercentage = if ($Script:Stats.CurrentCheck.TotalTorrents -gt 0) {
            [math]::Round(($Script:Stats.CurrentCheck.OkTorrents / $Script:Stats.CurrentCheck.TotalTorrents) * 100, 2)
        } else { 0 }
        
        $brokenPercentage = if ($Script:Stats.CurrentCheck.TotalTorrents -gt 0) {
            [math]::Round(($Script:Stats.CurrentCheck.BrokenFound / $Script:Stats.CurrentCheck.TotalTorrents) * 100, 2)
        } else { 0 }
        
        $repairPercentage = if ($Script:Stats.CurrentCheck.TotalTorrents -gt 0) {
            [math]::Round(($Script:Stats.CurrentCheck.UnderRepairFound / $Script:Stats.CurrentCheck.TotalTorrents) * 100, 2)
        } else { 0 }
        
        Write-Host ("  OK Torrents:               {0} ({1}%)" -f $Script:Stats.CurrentCheck.OkTorrents, $okPercentage) -ForegroundColor Green
        Write-Host ("  Broken:                    {0} ({1}%)" -f $Script:Stats.CurrentCheck.BrokenFound, $brokenPercentage) -ForegroundColor $(if ($Script:Stats.CurrentCheck.BrokenFound -gt 0) { "Yellow" } else { "Gray" })
        Write-Host ("  Under Repair:              {0} ({1}%)" -f $Script:Stats.CurrentCheck.UnderRepairFound, $repairPercentage) -ForegroundColor $(if ($Script:Stats.CurrentCheck.UnderRepairFound -gt 0) { "Cyan" } else { "Gray" })
        Write-Host ""
    }
    
    Write-Host "CURRENT CHECK RESULTS:" -ForegroundColor Yellow
    Write-Host "  Broken Torrents:           $($Script:Stats.CurrentCheck.BrokenFound)" -ForegroundColor $(if ($Script:Stats.CurrentCheck.BrokenFound -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Under Repair:              $($Script:Stats.CurrentCheck.UnderRepairFound)" -ForegroundColor $(if ($Script:Stats.CurrentCheck.UnderRepairFound -gt 0) { "Cyan" } else { "Gray" })
    Write-Host "  Repairs Triggered:         $($Script:Stats.CurrentCheck.RepairsTriggered)" -ForegroundColor Green
    
    if ($Script:Stats.CurrentCheck.BrokenNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Broken Torrents:" -ForegroundColor Yellow
        foreach ($name in $Script:Stats.CurrentCheck.BrokenNames) {
            Write-Host "    - $name" -ForegroundColor Yellow
        }
    }
    
    if ($Script:Stats.CurrentCheck.UnderRepairNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Under Repair:" -ForegroundColor Cyan
        foreach ($name in $Script:Stats.CurrentCheck.UnderRepairNames) {
            Write-Host "    - $name" -ForegroundColor Cyan
        }
    }
    
    # Comparison with previous check (if exists)
    if ($Script:Stats.PreviousCheck.TriggeredHashes.Count -gt 0) {
        Write-Host ""
        Write-Host "COMPARISON WITH PREVIOUS CHECK:" -ForegroundColor Cyan
        
        # Calculate what was repaired (was in previous check, now not in any list)
        $repairedCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.TriggeredHashes) {
            if (($Script:Stats.CurrentCheck.BrokenHashes -notcontains $hash) -and 
                ($Script:Stats.CurrentCheck.UnderRepairHashes -notcontains $hash)) {
                $repairedCount++
            }
        }
        
        # Calculate what moved from broken to under repair
        $movedToRepairCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.BrokenHashes) {
            if ($Script:Stats.CurrentCheck.UnderRepairHashes -contains $hash) {
                $movedToRepairCount++
            }
        }
        
        # Calculate what's still broken
        $stillBrokenCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.BrokenHashes) {
            if ($Script:Stats.CurrentCheck.BrokenHashes -contains $hash) {
                $stillBrokenCount++
            }
        }
        
        # Calculate what's still under repair
        $stillUnderRepairCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.UnderRepairHashes) {
            if ($Script:Stats.CurrentCheck.UnderRepairHashes -contains $hash) {
                $stillUnderRepairCount++
            }
        }
        
        # Calculate new broken (not in previous check at all)
        $newBrokenCount = 0
        foreach ($hash in $Script:Stats.CurrentCheck.BrokenHashes) {
            if (($Script:Stats.PreviousCheck.BrokenHashes -notcontains $hash) -and 
                ($Script:Stats.PreviousCheck.UnderRepairHashes -notcontains $hash)) {
                $newBrokenCount++
            }
        }
        
        Write-Host "  Successfully Repaired:     $repairedCount" -ForegroundColor $(if ($repairedCount -gt 0) { "Green" } else { "Gray" })
        Write-Host "  Moved to Repair:           $movedToRepairCount" -ForegroundColor $(if ($movedToRepairCount -gt 0) { "Cyan" } else { "Gray" })
        Write-Host "  Still Broken:              $stillBrokenCount" -ForegroundColor $(if ($stillBrokenCount -gt 0) { "Yellow" } else { "Gray" })
        Write-Host "  Still Under Repair:        $stillUnderRepairCount" -ForegroundColor $(if ($stillUnderRepairCount -gt 0) { "Cyan" } else { "Gray" })
        Write-Host "  New Broken:                $newBrokenCount" -ForegroundColor $(if ($newBrokenCount -gt 0) { "Red" } else { "Gray" })
        
        # Calculate success rate
        if ($Script:Stats.PreviousCheck.TriggeredHashes.Count -gt 0) {
            $successRate = [math]::Round(($repairedCount / $Script:Stats.PreviousCheck.TriggeredHashes.Count) * 100, 1)
            Write-Host ("  Repair Success Rate:       {0}%" -f $successRate) -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
        }
    }
    
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Start-MonitoringLoop {
    Write-Banner "ZURG BROKEN TORRENT MONITOR v2.2.1"
    
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
