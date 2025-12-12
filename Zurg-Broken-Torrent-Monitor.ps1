# ============================================================================
# Zurg Broken Torrent Monitor & Repair Tool v2.5.2
# ============================================================================
# New in v2.5.2:
#   - Verification runs ONLY on startup (if enabled) - not every cycle
#   - Manual verification available anytime via V key
#   - Toggle settings are SAVED and persist between restarts
#   - Settings stored in zurg-monitor-settings.json
#
# Previous in v2.5.1:
#   - FIXED: Verification logic correctly parses Zurg's State/File States
#   - Live progress timer during verification
#   - Countdown timer showing time until next check
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
    [string]$SettingsFile = "zurg-monitor-settings.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$RunOnce,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipStartupVerification,  # Skip verification even if enabled
    
    [Parameter(Mandatory=$false)]
    [int]$VerifyDelayMs = 50  # Delay between verifications to avoid overwhelming server
)

$ErrorActionPreference = "Continue"

# Script-level settings (will be loaded from file or use defaults)
$Script:AutoRepairEnabled = $false
$Script:AutoVerifyEnabled = $false  # Verification on startup if enabled
$Script:SettingsLoaded = $false

# ============================================================================
# SETTINGS PERSISTENCE FUNCTIONS
# ============================================================================

function Get-SettingsPath {
    # Store settings in same directory as the script/log file
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }
    return Join-Path $scriptDir $SettingsFile
}

function Load-Settings {
    $settingsPath = Get-SettingsPath
    
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            $Script:AutoRepairEnabled = [bool]$settings.AutoRepair
            $Script:AutoVerifyEnabled = [bool]$settings.AutoVerify
            $Script:SettingsLoaded = $true
            
            Write-Log "Loaded settings from $settingsPath" "DEBUG"
            Write-Log "  AutoRepair: $($Script:AutoRepairEnabled)" "DEBUG"
            Write-Log "  AutoVerify: $($Script:AutoVerifyEnabled)" "DEBUG"
            
            return $true
        }
        catch {
            Write-Log "Failed to load settings: $($_.Exception.Message)" "WARN"
            return $false
        }
    }
    else {
        Write-Log "No settings file found, using defaults" "DEBUG"
        return $false
    }
}

function Save-Settings {
    $settingsPath = Get-SettingsPath
    
    try {
        $settings = @{
            AutoRepair = $Script:AutoRepairEnabled
            AutoVerify = $Script:AutoVerifyEnabled
            LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $settings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
        
        Write-Log "Settings saved to $settingsPath" "DEBUG"
        return $true
    }
    catch {
        Write-Log "Failed to save settings: $($_.Exception.Message)" "WARN"
        return $false
    }
}

# ============================================================================
# MEMORY MANAGEMENT FUNCTIONS
# ============================================================================

function Invoke-MemoryCleanup {
    param(
        [switch]$Force,
        [switch]$Silent
    )
    
    # Get memory before cleanup
    $memBefore = [System.GC]::GetTotalMemory($false) / 1MB
    
    # Clear any large temporary variables in the current scope
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    # Get memory after cleanup
    $memAfter = [System.GC]::GetTotalMemory($true) / 1MB
    $freed = $memBefore - $memAfter
    
    if (-not $Silent -and $freed -gt 1) {
        Write-Log "Memory cleanup: freed $([math]::Round($freed, 2)) MB (now using $([math]::Round($memAfter, 2)) MB)" "DEBUG"
    }
    
    return @{
        Before = [math]::Round($memBefore, 2)
        After = [math]::Round($memAfter, 2)
        Freed = [math]::Round($freed, 2)
    }
}

function Get-MemoryUsage {
    $memMB = [System.GC]::GetTotalMemory($false) / 1MB
    return [math]::Round($memMB, 2)
}

function Clear-OldMismatches {
    # Limit the number of stored mismatches to prevent memory bloat
    $maxMismatches = 100
    
    if ($Script:Stats.CurrentMismatches.Count -gt $maxMismatches) {
        Write-Log "Trimming mismatch list from $($Script:Stats.CurrentMismatches.Count) to $maxMismatches" "DEBUG"
        $Script:Stats.CurrentMismatches = $Script:Stats.CurrentMismatches | Select-Object -First $maxMismatches
    }
}

$Script:Stats = @{
    TotalChecks = 0
    BrokenFound = 0
    UnderRepairFound = 0
    UnrepairableFound = 0
    RepairsTriggered = 0
    DeletionsTriggered = 0
    LastCheck = $null
    LastBrokenFound = $null
    # Verification stats
    TotalVerifications = 0
    TorrentsVerified = 0
    MismatchesFound = 0
    MismatchesCorrected = 0
    LastVerification = $null
    CurrentMismatches = @()  # Currently known mismatches
    CurrentCheck = @{
        BrokenFound = 0
        UnderRepairFound = 0
        UnrepairableFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
        UnderRepairHashes = @()
        UnderRepairNames = @()
        UnrepairableHashes = @()
        UnrepairableNames = @()
        UnrepairableReasons = @()
        # Verification results
        VerifiedCount = 0
        MismatchCount = 0
    }
    PreviousCheck = @{
        BrokenHashes = @()
        UnderRepairHashes = @()
        TriggeredHashes = @()
    }
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

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

function Format-TimeSpan {
    param([TimeSpan]$TimeSpan)
    
    # Handle negative or zero timespan
    if ($TimeSpan.TotalSeconds -le 0) {
        return "0s"
    }
    
    if ($TimeSpan.TotalHours -ge 1) {
        return "{0:0}h {1:0}m {2:0}s" -f [math]::Floor($TimeSpan.TotalHours), $TimeSpan.Minutes, $TimeSpan.Seconds
    }
    elseif ($TimeSpan.TotalMinutes -ge 1) {
        return "{0:0}m {1:0}s" -f [math]::Floor($TimeSpan.TotalMinutes), $TimeSpan.Seconds
    }
    else {
        return "{0:0}s" -f [math]::Floor($TimeSpan.TotalSeconds)
    }
}

# ============================================================================
# CONNECTION & AUTH FUNCTIONS
# ============================================================================

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

# ============================================================================
# TORRENT FETCH FUNCTIONS
# ============================================================================

function Get-ZurgTorrentsByState {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("status_broken", "status_under_repair", "status_ok")]
        [string]$State
    )
    
    try {
        $stateName = switch ($State) {
            "status_broken" { "broken" }
            "status_under_repair" { "under repair" }
            "status_ok" { "OK" }
        }
        Write-Log "Fetching $stateName torrents from Zurg..." "DEBUG"
        $headers = Get-AuthHeaders
        
        $url = "$ZurgUrl/manage/?state=$State"
        Write-Log "Fetching: $url" "DEBUG"
        
        # Show spinner for OK torrents since they can be numerous
        $showSpinner = ($State -eq "status_ok")
        
        try {
            if ($showSpinner) {
                Write-Host "    Downloading torrent list from Zurg..." -NoNewline -ForegroundColor Gray
                [Console]::Out.Flush()
            }
            
            $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 60 -ErrorAction Stop -UseBasicParsing
            $content = $response.Content
            
            if ($showSpinner) {
                Write-Host " Done! ($([math]::Round($content.Length / 1024))KB)" -ForegroundColor Gray
                Write-Host "    Parsing torrent data..." -NoNewline -ForegroundColor Gray
                [Console]::Out.Flush()
            }
            
            Write-Log "Successfully fetched $stateName torrents page (length: $($content.Length) bytes)" "DEBUG"
        }
        catch {
            if ($showSpinner) {
                Write-Host " Failed!" -ForegroundColor Red
            }
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
                
                $typeLabel = switch ($State) {
                    "status_broken" { "Broken" }
                    "status_under_repair" { "Under Repair" }
                    "status_ok" { "OK" }
                }
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = $State
                    Type = $typeLabel
                    Reason = ""
                    ReportedStatus = $typeLabel
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
                
                $typeLabel = switch ($State) {
                    "status_broken" { "Broken" }
                    "status_under_repair" { "Under Repair" }
                    "status_ok" { "OK" }
                }
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    State = $State
                    Type = $typeLabel
                    Reason = ""
                    ReportedStatus = $typeLabel
                }
            }
        }
        
        Write-Log "Successfully parsed $($torrents.Count) $stateName torrent(s)" "DEBUG"
        
        if ($showSpinner) {
            Write-Host " Found $($torrents.Count) torrents" -ForegroundColor Gray
        }
        
        return $torrents
    }
    catch {
        Write-Log "Error getting $stateName torrents: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

function Get-ZurgUnrepairableTorrents {
    try {
        Write-Log "Fetching unrepairable torrents from Zurg..." "DEBUG"
        $headers = Get-AuthHeaders
        
        $url = "$ZurgUrl/manage/?state=status_cannot_repair"
        Write-Log "Fetching: $url" "DEBUG"
        
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 30 -ErrorAction Stop -UseBasicParsing
            $content = $response.Content
            
            Write-Log "Successfully fetched unrepairable torrents page (length: $($content.Length) bytes)" "DEBUG"
        }
        catch {
            Write-Log "Failed to fetch unrepairable torrents page: $($_.Exception.Message)" "ERROR"
            return $null
        }
        
        $torrents = @()
        $processedHashes = @{}
        
        # Look for table rows with torrent data
        $rowPattern = '<tr[^>]*class="torrent-row"[^>]*data-hash="([a-fA-F0-9]{40})"[^>]*data-name="([^"]+)"[^>]*>'
        $rowMatches = [regex]::Matches($content, $rowPattern)
        
        Write-Log "Found $($rowMatches.Count) unrepairable torrent row(s) using data-name pattern" "DEBUG"
        
        if ($rowMatches.Count -gt 0) {
            foreach ($match in $rowMatches) {
                $hash = $match.Groups[1].Value.ToLower()
                $torrentName = [System.Web.HttpUtility]::HtmlDecode($match.Groups[2].Value.Trim())
                
                if ($processedHashes.ContainsKey($hash)) {
                    continue
                }
                $processedHashes[$hash] = $true
                
                # Extract reason from state badge title
                $contextStart = [Math]::Max(0, $match.Index)
                $contextEnd = [Math]::Min($content.Length, $match.Index + 1000)
                $context = $content.Substring($contextStart, $contextEnd - $contextStart)
                
                $reason = "Unknown reason"
                $reasonPattern = 'title="Unrepairable:\s*([^"]+)"'
                $reasonMatch = [regex]::Match($context, $reasonPattern)
                if ($reasonMatch.Success) {
                    $reason = $reasonMatch.Groups[1].Value.Trim()
                }
                
                Write-Log "  Found unrepairable torrent: $torrentName - Reason: $reason" "DEBUG"
                
                $torrents += @{
                    Hash = $hash
                    Name = $torrentName
                    Reason = $reason
                    State = "status_cannot_repair"
                    Type = "Unrepairable"
                    ReportedStatus = "Unrepairable"
                }
            }
        }
        else {
            # Fallback: Try simple data-hash pattern for older Zurg versions
            Write-Log "No torrent-row pattern found, trying fallback..." "DEBUG"
            $hashPattern = 'data-hash="([a-fA-F0-9]{40})"'
            $hashMatches = [regex]::Matches($content, $hashPattern)
            
            foreach ($match in $hashMatches) {
                $hash = $match.Groups[1].Value.ToLower()
                
                if ($processedHashes.ContainsKey($hash)) {
                    continue
                }
                $processedHashes[$hash] = $true
                
                $torrents += @{
                    Hash = $hash
                    Name = "Unknown ($hash)"
                    Reason = "Unknown reason"
                    State = "status_cannot_repair"
                    Type = "Unrepairable"
                    ReportedStatus = "Unrepairable"
                }
            }
        }
        
        Write-Log "Successfully parsed $($torrents.Count) unrepairable torrent(s)" "DEBUG"
        return ,$torrents
    }
    catch {
        Write-Log "Error getting unrepairable torrents: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

# ============================================================================
# HEALTH VERIFICATION FUNCTIONS (v2.5.1 - CORRECTED LOGIC)
# ============================================================================

function Get-TorrentHealthStatus {
    param(
        [string]$Hash,
        [string]$Name
    )
    
    <#
    .SYNOPSIS
    Check a torrent's actual health status from Zurg's detail page.
    
    .DESCRIPTION
    Parses the torrent detail page to find:
    - State: Should be 'Active' for healthy torrents (in badge after info-label)
    - File States: Should be 'OK: X' where X is number of OK files (in badge)
    
    Zurg HTML structure (from debug):
      <td class="info-label">State</td> ... <span class="badge ">Active</span>
      <td class="info-label">File States</td> ... <span class="badge">OK: 1</span>
    
    A mismatch occurs when:
    - State badge is NOT 'Active'
    - File States badge does NOT start with 'OK:'
    #>
    
    try {
        $headers = Get-AuthHeaders
        $url = "$ZurgUrl/manage/$Hash/"
        
        $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 15 -ErrorAction Stop -UseBasicParsing
        $content = $response.Content
        
        # Initialize result
        $result = @{
            IsHealthy = $true
            TorrentState = "Unknown"
            FileState = "Unknown"
            Reason = ""
        }
        
        # ================================================================
        # PATTERN 1: Find State value
        # Look for: info-label">State</td> ... <span class="badge ...">VALUE</span>
        # ================================================================
        
        # Find the State label position
        $stateLabel = 'info-label">State</td>'
        $stateLabelIndex = $content.IndexOf($stateLabel)
        
        if ($stateLabelIndex -gt 0) {
            # Look for the next badge after the State label (within 500 chars)
            $stateSection = $content.Substring($stateLabelIndex, [Math]::Min(500, $content.Length - $stateLabelIndex))
            
            # Pattern: <span class="badge ...">VALUE</span>
            if ($stateSection -match '<span\s+class="badge[^"]*">([^<]+)</span>') {
                $result.TorrentState = $Matches[1].Trim()
            }
        }
        
        # ================================================================
        # PATTERN 2: Find File States value
        # Look for: info-label">File States</td> ... <span class="badge">OK: 1</span>
        # ================================================================
        
        # Find the File States label position
        $fileStatesLabel = 'info-label">File States</td>'
        $fileStatesIndex = $content.IndexOf($fileStatesLabel)
        
        if ($fileStatesIndex -gt 0) {
            # Look for the next badge after the File States label (within 500 chars)
            $fileSection = $content.Substring($fileStatesIndex, [Math]::Min(500, $content.Length - $fileStatesIndex))
            
            # Pattern: <span class="badge...">VALUE</span>
            if ($fileSection -match '<span\s+class="badge[^"]*">([^<]+)</span>') {
                $result.FileState = $Matches[1].Trim()
            }
        }
        
        # ================================================================
        # DETERMINE HEALTH STATUS
        # ================================================================
        
        $reasons = @()
        
        # Check Torrent State - must be "Active"
        if ($result.TorrentState -ne "Unknown") {
            if ($result.TorrentState -ne "Active") {
                $result.IsHealthy = $false
                $reasons += "State: $($result.TorrentState) (expected: Active)"
            }
        }
        
        # Check File States - must start with "OK:" (note: Zurg uses "OK: " with space)
        if ($result.FileState -ne "Unknown") {
            # Zurg format is "OK: 1" with space after colon
            if (-not ($result.FileState -match '^OK[:\s]')) {
                $result.IsHealthy = $false
                $reasons += "File States: $($result.FileState) (expected: OK: X)"
            }
        }
        
        # Combine reasons
        if ($reasons.Count -gt 0) {
            $result.Reason = $reasons -join "; "
        }
        
        return $result
    }
    catch {
        # If we can't fetch the page, don't flag as unhealthy - could be transient
        return @{
            IsHealthy = $true  # Assume healthy if we can't check
            TorrentState = "Unknown"
            FileState = "Unknown"
            Reason = "Could not verify: $($_.Exception.Message)"
            Error = $true
        }
    }
}

function Invoke-HealthVerification {
    param(
        [switch]$Compact  # Show compact progress (for auto-verify during monitoring)
    )
    
    $startTime = Get-Date
    
    if (-not $Compact) {
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host "  HEALTH VERIFICATION STARTING" -ForegroundColor Cyan
        Write-Host "======================================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Always show this so user knows something is happening
    Write-Host "  Fetching all OK torrents from Zurg..." -ForegroundColor Yellow
    [Console]::Out.Flush()
    
    $okTorrents = Get-ZurgTorrentsByState -State "status_ok"
    
    if ($null -eq $okTorrents -or $okTorrents.Count -eq 0) {
        Write-Log "No OK torrents found to verify" "INFO"
        Write-Host "  No OK torrents found to verify." -ForegroundColor Green
        return @{
            Verified = 0
            Mismatches = @()
            TotalOK = 0
            Duration = (Get-Date) - $startTime
        }
    }
    
    $totalCount = $okTorrents.Count
    Write-Log "Found $totalCount torrents marked as OK - verifying ALL" "INFO"
    
    # Calculate estimated time
    $estimatedSeconds = [math]::Ceiling($totalCount * ($VerifyDelayMs + 150) / 1000)
    $estimatedTime = [TimeSpan]::FromSeconds($estimatedSeconds)
    
    Write-Host "  Found " -NoNewline -ForegroundColor White
    Write-Host "$totalCount" -NoNewline -ForegroundColor Green
    Write-Host " OK torrents to verify" -ForegroundColor White
    Write-Host "  Estimated time: " -NoNewline -ForegroundColor White
    Write-Host "$(Format-TimeSpan $estimatedTime)" -ForegroundColor Yellow
    Write-Host "  Memory: $(Get-MemoryUsage) MB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Verifying (this may take several minutes for large libraries)..." -ForegroundColor Cyan
    Write-Host ""
    [Console]::Out.Flush()
    
    # Use ArrayList for better memory efficiency (avoids array copy on each +=)
    $mismatches = [System.Collections.ArrayList]::new()
    $verified = 0
    $errors = 0
    $lastProgressUpdate = [DateTime]::MinValue
    $lastMemoryCleanup = Get-Date
    
    foreach ($torrent in $okTorrents) {
        $verified++
        
        # Update progress display
        $now = Get-Date
        $elapsed = $now - $startTime
        
        # Calculate progress
        $percentComplete = [math]::Round(($verified / $totalCount) * 100, 1)
        $torrentsPerSecond = if ($elapsed.TotalSeconds -gt 0) { $verified / $elapsed.TotalSeconds } else { 0 }
        $remainingTorrents = $totalCount - $verified
        $estimatedRemaining = if ($torrentsPerSecond -gt 0) { 
            [TimeSpan]::FromSeconds($remainingTorrents / $torrentsPerSecond) 
        } else { 
            [TimeSpan]::Zero 
        }
        
        # Update display every second or at milestones
        $shouldUpdate = (($now - $lastProgressUpdate).TotalSeconds -ge 1) -or 
                        ($verified -eq 1) -or 
                        ($verified -eq $totalCount) -or
                        ($verified % 100 -eq 0)
        
        if ($shouldUpdate) {
            $barWidth = 30
            $filledWidth = [math]::Floor(($verified / $totalCount) * $barWidth)
            $filledWidth = [Math]::Max(0, [Math]::Min($barWidth, $filledWidth))  # Clamp to 0-barWidth
            $emptyWidth = $barWidth - $filledWidth
            $progressBar = ("█" * $filledWidth) + ("░" * $emptyWidth)
            
            # Clear line and write progress
            $memUsage = Get-MemoryUsage
            $statusLine = "  [$progressBar] $percentComplete% | $verified/$totalCount | " +
                         "ETA: $(Format-TimeSpan $estimatedRemaining) | " +
                         "Mismatches: $($mismatches.Count) | Mem: ${memUsage}MB"
            
            # Pad to overwrite previous content
            $paddedLine = $statusLine.PadRight(110)
            
            Write-Host "`r$paddedLine" -NoNewline -ForegroundColor Gray
            [Console]::Out.Flush()
            
            $lastProgressUpdate = $now
        }
        
        # Periodic memory cleanup every 1000 torrents
        if ($verified % 1000 -eq 0) {
            $null = Invoke-MemoryCleanup -Silent
        }
        
        # Check actual status
        $healthResult = Get-TorrentHealthStatus -Hash $torrent['Hash'] -Name $torrent['Name']
        
        if ($healthResult.Error) {
            $errors++
        }
        
        # Only flag as mismatch if actually unhealthy
        if (-not $healthResult.IsHealthy) {
            $null = $mismatches.Add(@{
                Hash = $torrent['Hash']
                Name = $torrent['Name']
                ReportedStatus = "OK"
                ActualState = $healthResult.TorrentState
                ActualFileState = $healthResult.FileState
                Reason = $healthResult.Reason
                Type = "Mismatch"
                State = "mismatch"
            })
        }
        
        # Small delay to avoid hammering the server
        if ($VerifyDelayMs -gt 0) {
            Start-Sleep -Milliseconds $VerifyDelayMs
        }
    }
    
    # Clear the okTorrents array to free memory
    $okTorrents = $null
    
    # Final progress update
    $totalDuration = (Get-Date) - $startTime
    Write-Host ""  # New line after progress bar
    Write-Host ""
    
    # Convert ArrayList to array for return
    $mismatchArray = @($mismatches.ToArray())
    $mismatches.Clear()
    $mismatches = $null
    
    # Update stats
    $Script:Stats.TotalVerifications++
    $Script:Stats.TorrentsVerified += $verified
    $Script:Stats.MismatchesFound += $mismatchArray.Count
    $Script:Stats.LastVerification = Get-Date
    $Script:Stats.CurrentCheck.VerifiedCount = $verified
    $Script:Stats.CurrentCheck.MismatchCount = $mismatchArray.Count
    
    # Update current mismatches list (with limit)
    foreach ($mismatch in $mismatchArray) {
        # Check if already in list
        $existing = $Script:Stats.CurrentMismatches | Where-Object { $_['Hash'] -eq $mismatch['Hash'] }
        if (-not $existing) {
            $Script:Stats.CurrentMismatches += $mismatch
        }
    }
    
    # Trim old mismatches to prevent memory bloat
    Clear-OldMismatches
    
    # Memory cleanup after verification
    $null = Invoke-MemoryCleanup -Silent
    
    # Summary - always show results
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  HEALTH VERIFICATION COMPLETE" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Torrents Verified:   $verified" -ForegroundColor White
    Write-Host "  Mismatches Found:    " -NoNewline -ForegroundColor White
    if ($mismatchArray.Count -gt 0) {
        Write-Host "$($mismatchArray.Count)" -ForegroundColor Yellow
    }
    else {
        Write-Host "0 (All healthy!)" -ForegroundColor Green
    }
    Write-Host "  Verification Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "  Total Duration:      $(Format-TimeSpan $totalDuration)" -ForegroundColor White
    Write-Host "  Memory Usage:        $(Get-MemoryUsage) MB" -ForegroundColor Gray
    Write-Host ""
    
    # Show mismatches if any (limit to first 10 in compact mode)
    if ($mismatchArray.Count -gt 0) {
        Write-Host "  MISMATCHED TORRENTS:" -ForegroundColor Yellow
        $showCount = if ($Compact) { [Math]::Min($mismatchArray.Count, 10) } else { $mismatchArray.Count }
        
        for ($i = 0; $i -lt $showCount; $i++) {
            $mismatch = $mismatchArray[$i]
            Write-Host "    - $($mismatch['Name'])" -ForegroundColor Yellow
            Write-Host "      State: $($mismatch['ActualState']) | File States: $($mismatch['ActualFileState'])" -ForegroundColor DarkYellow
            Write-Host "      Reason: $($mismatch['Reason'])" -ForegroundColor DarkYellow
        }
        
        if ($Compact -and $mismatchArray.Count -gt 10) {
            Write-Host "    ... and $($mismatchArray.Count - 10) more (enter Management UI to see all)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Log "Health verification complete: $verified checked, $($mismatchArray.Count) mismatch(es) found in $(Format-TimeSpan $totalDuration)" "INFO"
    
    return @{
        Verified = $verified
        Mismatches = $mismatchArray
        TotalOK = $totalCount
        Duration = $totalDuration
        Errors = $errors
    }
}

# ============================================================================
# TORRENT ACTION FUNCTIONS
# ============================================================================

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

function Invoke-TorrentDelete {
    param(
        [string]$Hash,
        [string]$Name
    )
    
    try {
        Write-Log "Deleting torrent: $Name" "WARN"
        $headers = Get-AuthHeaders
        
        $deleteUrl = "$ZurgUrl/manage/$Hash/delete"
        Write-Log "  Delete URL: $deleteUrl" "DEBUG"
        
        try {
            $response = Invoke-RestMethod -Uri $deleteUrl -Method Post -Headers $headers -TimeoutSec 30 -ErrorAction Stop
            Write-Log "Successfully deleted torrent: $Name" "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to delete torrent $Name : $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Exception deleting torrent: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================================================
# UNIFIED TORRENT MANAGEMENT UI
# ============================================================================

function Get-AllTorrentsForManagement {
    param(
        [switch]$IncludeMismatches
    )
    
    Write-Host "Fetching all torrent data..." -ForegroundColor Yellow
    
    $allTorrents = @()
    
    # Get broken torrents
    $brokenTorrents = Get-ZurgTorrentsByState -State "status_broken"
    if ($null -ne $brokenTorrents -and $brokenTorrents.Count -gt 0) {
        $allTorrents += $brokenTorrents
    }
    
    # Get under repair torrents
    $underRepairTorrents = Get-ZurgTorrentsByState -State "status_under_repair"
    if ($null -ne $underRepairTorrents -and $underRepairTorrents.Count -gt 0) {
        $allTorrents += $underRepairTorrents
    }
    
    # Get unrepairable torrents
    $unrepairableTorrents = Get-ZurgUnrepairableTorrents
    if ($null -ne $unrepairableTorrents -and $unrepairableTorrents.Count -gt 0) {
        $allTorrents += $unrepairableTorrents
    }
    
    # Include current mismatches if requested
    if ($IncludeMismatches -and $Script:Stats.CurrentMismatches.Count -gt 0) {
        foreach ($mismatch in $Script:Stats.CurrentMismatches) {
            # Check if not already in list (avoid duplicates)
            $exists = $allTorrents | Where-Object { $_['Hash'] -eq $mismatch['Hash'] }
            if (-not $exists) {
                $allTorrents += $mismatch
            }
        }
    }
    
    return ,$allTorrents
}

function Show-TorrentManagement {
    param(
        [array]$Torrents
    )
    
    if ($null -eq $Torrents -or $Torrents.Count -eq 0) {
        Write-Host "`nNo torrents to manage." -ForegroundColor Green
        Write-Host "Press any key to return to monitoring..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Initialize filter state
    $filterState = "*"  # B=Broken, U=Under Repair, C=Cannot Repair, M=Mismatch, *=All
    $searchText = ""
    $reasonFilter = ""
    
    # Initialize selection
    $selected = @{}
    for ($i = 0; $i -lt $Torrents.Count; $i++) {
        $selected[$i] = $false
    }
    
    while ($true) {
        Clear-Host
        
        # Apply filters to get visible torrents
        $visibleTorrents = @()
        $visibleIndices = @()
        
        for ($i = 0; $i -lt $Torrents.Count; $i++) {
            $torrent = $Torrents[$i]
            $show = $true
            
            # Filter by state
            if ($filterState -ne "*") {
                $typeChar = switch ($torrent['Type']) {
                    "Broken" { "B" }
                    "Under Repair" { "U" }
                    "Unrepairable" { "C" }
                    "Mismatch" { "M" }
                    default { "?" }
                }
                if ($typeChar -ne $filterState) {
                    $show = $false
                }
            }
            
            # Filter by search text
            if ($show -and $searchText -ne "") {
                if ($torrent['Name'] -notlike "*$searchText*") {
                    $show = $false
                }
            }
            
            # Filter by reason
            if ($show -and $reasonFilter -ne "") {
                if ($torrent['Reason'] -notlike "*$reasonFilter*") {
                    $show = $false
                }
            }
            
            if ($show) {
                $visibleTorrents += $torrent
                $visibleIndices += $i
            }
        }
        
        # Count by type
        $brokenCount = ($Torrents | Where-Object { $_['Type'] -eq "Broken" }).Count
        $underRepairCount = ($Torrents | Where-Object { $_['Type'] -eq "Under Repair" }).Count
        $unrepairableCount = ($Torrents | Where-Object { $_['Type'] -eq "Unrepairable" }).Count
        $mismatchCount = ($Torrents | Where-Object { $_['Type'] -eq "Mismatch" }).Count
        
        # Header
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host "  TORRENT MANAGEMENT CENTER v2.5.1" -ForegroundColor Magenta
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host ""
        
        # Summary line
        Write-Host "Total: $($Torrents.Count) torrents  |  " -NoNewline -ForegroundColor White
        Write-Host "Broken: $brokenCount" -NoNewline -ForegroundColor Yellow
        Write-Host "  |  " -NoNewline -ForegroundColor White
        Write-Host "Under Repair: $underRepairCount" -NoNewline -ForegroundColor Cyan
        Write-Host "  |  " -NoNewline -ForegroundColor White
        Write-Host "Unrepairable: $unrepairableCount" -NoNewline -ForegroundColor Red
        if ($mismatchCount -gt 0) {
            Write-Host "  |  " -NoNewline -ForegroundColor White
            Write-Host "Mismatch: $mismatchCount" -ForegroundColor Magenta
        }
        else {
            Write-Host ""
        }
        Write-Host ""
        
        # Status line
        $autoRepairStatus = if ($Script:AutoRepairEnabled) { "ON" } else { "OFF" }
        $autoRepairColor = if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" }
        $autoVerifyStatus = if ($Script:AutoVerifyEnabled) { "ON (startup)" } else { "OFF" }
        $autoVerifyColor = if ($Script:AutoVerifyEnabled) { "Green" } else { "Yellow" }
        
        Write-Host "AutoRepair: " -NoNewline -ForegroundColor Gray
        Write-Host $autoRepairStatus -NoNewline -ForegroundColor $autoRepairColor
        Write-Host "  |  AutoVerify: " -NoNewline -ForegroundColor Gray
        Write-Host $autoVerifyStatus -NoNewline -ForegroundColor $autoVerifyColor
        Write-Host "  |  Settings: " -NoNewline -ForegroundColor Gray
        Write-Host "Saved" -ForegroundColor DarkGray
        Write-Host ""
        
        # Active filters display
        $hasFilters = ($filterState -ne "*") -or ($searchText -ne "") -or ($reasonFilter -ne "")
        if ($hasFilters) {
            Write-Host "ACTIVE FILTERS:" -ForegroundColor Cyan
            if ($filterState -ne "*") {
                $stateName = switch ($filterState) {
                    "B" { "Broken" }
                    "U" { "Under Repair" }
                    "C" { "Unrepairable" }
                    "M" { "Mismatch" }
                }
                Write-Host "  State: $stateName" -ForegroundColor Yellow
            }
            if ($searchText -ne "") {
                Write-Host "  Search: `"$searchText`"" -ForegroundColor Yellow
            }
            if ($reasonFilter -ne "") {
                Write-Host "  Reason: `"$reasonFilter`"" -ForegroundColor Yellow
            }
            Write-Host "  Showing $($visibleTorrents.Count) of $($Torrents.Count) torrents" -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
        
        # Display visible torrents
        if ($visibleTorrents.Count -eq 0) {
            Write-Host ""
            Write-Host "  No torrents match current filters." -ForegroundColor Yellow
            Write-Host ""
        }
        else {
            Write-Host ""
            for ($v = 0; $v -lt $visibleTorrents.Count; $v++) {
                $torrent = $visibleTorrents[$v]
                $realIndex = $visibleIndices[$v]
                $checkbox = if ($selected[$realIndex]) { "[X]" } else { "[ ]" }
                $number = ($v + 1).ToString().PadLeft(3)
                
                # Type badge
                $typeColor = switch ($torrent['Type']) {
                    "Broken" { "Yellow" }
                    "Under Repair" { "Cyan" }
                    "Unrepairable" { "Red" }
                    "Mismatch" { "Magenta" }
                    default { "White" }
                }
                $typeBadge = switch ($torrent['Type']) {
                    "Broken" { "[BRK]" }
                    "Under Repair" { "[REP]" }
                    "Unrepairable" { "[BAD]" }
                    "Mismatch" { "[MIS]" }
                    default { "[???]" }
                }
                
                Write-Host "$number. $checkbox " -NoNewline
                Write-Host $typeBadge -NoNewline -ForegroundColor $typeColor
                Write-Host " $($torrent['Name'])" -ForegroundColor White
                
                # Show reason for unrepairable or mismatch torrents
                if (($torrent['Type'] -eq "Unrepairable" -or $torrent['Type'] -eq "Mismatch") -and $torrent['Reason'] -ne "") {
                    Write-Host "          Reason: " -NoNewline -ForegroundColor Gray
                    Write-Host $torrent['Reason'] -ForegroundColor DarkYellow
                }
            }
            Write-Host ""
        }
        
        Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        
        # Commands section
        Write-Host "SELECTION:" -ForegroundColor Yellow
        Write-Host "  [#] [#-#] [#,#]  Toggle selection (single, range, or list)" -ForegroundColor White
        Write-Host "  [A] Select All visible    [N] Select None" -ForegroundColor White
        Write-Host ""
        Write-Host "FILTERS:" -ForegroundColor Yellow
        Write-Host "  [FB] Filter Broken   [FU] Filter Under Repair   [FC] Filter Unrepairable" -ForegroundColor White
        Write-Host "  [FM] Filter Mismatch [F*] Show All              [FS] Search by name" -ForegroundColor White
        Write-Host "  [FR] Filter by reason                           [FX] Clear all filters" -ForegroundColor White
        Write-Host ""
        Write-Host "BULK BY REASON:" -ForegroundColor Yellow
        Write-Host "  [BR] Select all matching a reason (e.g., 'infringing', 'not cached')" -ForegroundColor White
        Write-Host ""
        Write-Host "VERIFICATION:" -ForegroundColor Yellow
        Write-Host "  [V]  Run health verification now    [TV] Toggle AutoVerify on/off" -ForegroundColor White
        Write-Host ""
        Write-Host "ACTIONS:" -ForegroundColor Yellow
        Write-Host "  [R] Repair selected    [D] Delete selected    [T] Toggle AutoRepair" -ForegroundColor White
        Write-Host "  [L] Refresh list       [Q] Quit to monitoring" -ForegroundColor White
        Write-Host ""
        
        # Selected count
        $selectedCount = 0
        foreach ($idx in $visibleIndices) {
            if ($selected[$idx]) { $selectedCount++ }
        }
        Write-Host "Selected: $selectedCount torrent(s)" -ForegroundColor Cyan
        Write-Host ""
        
        $input = Read-Host "Enter command"
        $input = $input.Trim()
        $inputUpper = $input.ToUpper()
        
        # ==================== SELECTION COMMANDS ====================
        
        # Handle number input (supports ranges and comma-separated)
        if ($input -match '^[\d,\-\s]+$') {
            $numbersToToggle = @()
            $hasError = $false
            
            $parts = $input -split ','
            
            foreach ($part in $parts) {
                $part = $part.Trim()
                
                if ($part -match '^(\d+)-(\d+)$') {
                    $start = [int]$Matches[1]
                    $end = [int]$Matches[2]
                    
                    if ($start -gt $end) {
                        Write-Host "Invalid range: $part (start must be <= end)" -ForegroundColor Red
                        $hasError = $true
                        break
                    }
                    
                    for ($i = $start; $i -le $end; $i++) {
                        if ($i -ge 1 -and $i -le $visibleTorrents.Count) {
                            $numbersToToggle += $visibleIndices[($i - 1)]
                        }
                        else {
                            Write-Host "Invalid number in range: $i (valid: 1-$($visibleTorrents.Count))" -ForegroundColor Red
                            $hasError = $true
                            break
                        }
                    }
                }
                elseif ($part -match '^\d+$') {
                    $num = [int]$part
                    if ($num -ge 1 -and $num -le $visibleTorrents.Count) {
                        $numbersToToggle += $visibleIndices[($num - 1)]
                    }
                    else {
                        Write-Host "Invalid number: $num (valid: 1-$($visibleTorrents.Count))" -ForegroundColor Red
                        $hasError = $true
                        break
                    }
                }
                else {
                    Write-Host "Invalid format: $part" -ForegroundColor Red
                    $hasError = $true
                    break
                }
            }
            
            if (-not $hasError -and $numbersToToggle.Count -gt 0) {
                foreach ($idx in $numbersToToggle) {
                    $selected[$idx] = -not $selected[$idx]
                }
            }
            elseif ($hasError) {
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        # Select All visible
        elseif ($inputUpper -eq "A") {
            foreach ($idx in $visibleIndices) {
                $selected[$idx] = $true
            }
        }
        # Select None
        elseif ($inputUpper -eq "N") {
            foreach ($idx in $visibleIndices) {
                $selected[$idx] = $false
            }
        }
        
        # ==================== FILTER COMMANDS ====================
        
        elseif ($inputUpper -eq "FB") { $filterState = "B" }
        elseif ($inputUpper -eq "FU") { $filterState = "U" }
        elseif ($inputUpper -eq "FC") { $filterState = "C" }
        elseif ($inputUpper -eq "FM") { $filterState = "M" }
        elseif ($inputUpper -eq "F*") { $filterState = "*" }
        elseif ($inputUpper -eq "FS") {
            Write-Host ""
            $searchText = Read-Host "Enter search text (blank to clear)"
        }
        elseif ($inputUpper -eq "FR") {
            Write-Host ""
            Write-Host "Common reasons: infringing, not cached, download status: error, invalid file ids" -ForegroundColor Gray
            $reasonFilter = Read-Host "Enter reason filter (blank to clear)"
        }
        elseif ($inputUpper -eq "FX") {
            $filterState = "*"
            $searchText = ""
            $reasonFilter = ""
            Write-Host "All filters cleared." -ForegroundColor Green
            Start-Sleep -Milliseconds 500
        }
        
        # ==================== BULK BY REASON ====================
        
        elseif ($inputUpper -eq "BR") {
            Write-Host ""
            Write-Host "This will SELECT all torrents matching a reason pattern." -ForegroundColor Yellow
            Write-Host "Common patterns: infringing, not cached, download status: error" -ForegroundColor Gray
            $bulkReason = Read-Host "Enter reason pattern to match"
            
            if ($bulkReason -ne "") {
                $matchCount = 0
                for ($i = 0; $i -lt $Torrents.Count; $i++) {
                    if ($Torrents[$i]['Reason'] -like "*$bulkReason*") {
                        $selected[$i] = $true
                        $matchCount++
                    }
                }
                Write-Host "Selected $matchCount torrent(s) matching '$bulkReason'" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
        }
        
        # ==================== VERIFICATION COMMANDS ====================
        
        elseif ($inputUpper -eq "V") {
            Write-Host ""
            Write-Host "Starting health verification of ALL OK torrents..." -ForegroundColor Cyan
            Write-Host "This may take a while for large libraries." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to start, or 'Q' to cancel..." -ForegroundColor Gray
            $keyPress = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($keyPress.Character -ne 'Q' -and $keyPress.Character -ne 'q') {
                $result = Invoke-HealthVerification
                
                if ($result.Mismatches.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Add mismatches to management list? (y/n): " -NoNewline -ForegroundColor Cyan
                    $addChoice = Read-Host
                    if ($addChoice.ToLower() -eq 'y') {
                        # Refresh torrent list with mismatches
                        $newTorrents = Get-AllTorrentsForManagement -IncludeMismatches
                        if ($null -ne $newTorrents -and $newTorrents.Count -gt 0) {
                            $Torrents = $newTorrents
                            $selected = @{}
                            for ($i = 0; $i -lt $Torrents.Count; $i++) {
                                $selected[$i] = $false
                            }
                        }
                    }
                }
                
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        
        elseif ($inputUpper -eq "TV") {
            $Script:AutoVerifyEnabled = -not $Script:AutoVerifyEnabled
            $status = if ($Script:AutoVerifyEnabled) { "ENABLED" } else { "DISABLED" }
            Write-Host ""
            Write-Host "AutoVerify is now $status" -ForegroundColor $(if ($Script:AutoVerifyEnabled) { "Green" } else { "Yellow" })
            Write-Log "AutoVerify toggled to $status via Management UI" "INFO"
            
            # Save settings
            if (Save-Settings) {
                Write-Host "(Setting saved)" -ForegroundColor Gray
            }
            Start-Sleep -Seconds 1
        }
        
        # ==================== ACTION COMMANDS ====================
        
        elseif ($inputUpper -eq "T") {
            $Script:AutoRepairEnabled = -not $Script:AutoRepairEnabled
            $status = if ($Script:AutoRepairEnabled) { "ENABLED" } else { "DISABLED" }
            Write-Host ""
            Write-Host "AutoRepair is now $status" -ForegroundColor $(if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" })
            Write-Log "AutoRepair toggled to $status via Management UI" "INFO"
            
            # Save settings
            if (Save-Settings) {
                Write-Host "(Setting saved)" -ForegroundColor Gray
            }
            Start-Sleep -Seconds 1
        }
        
        elseif ($inputUpper -eq "R") {
            $toRepair = @()
            foreach ($idx in $visibleIndices) {
                if ($selected[$idx]) {
                    $toRepair += $Torrents[$idx]
                }
            }
            
            if ($toRepair.Count -eq 0) {
                Write-Host "`nNo torrents selected. Press any key to continue..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            
            Write-Host "`n" -NoNewline
            Write-Host "WARNING: " -ForegroundColor Red -NoNewline
            Write-Host "About to trigger repair for $($toRepair.Count) torrent(s)."
            Write-Host ""
            Write-Host "Torrents to repair:" -ForegroundColor Yellow
            foreach ($t in $toRepair) {
                Write-Host "  - [$($t['Type'])] $($t['Name'])" -ForegroundColor Gray
            }
            Write-Host ""
            $confirm = Read-Host "Type 'yes' to confirm"
            
            if ($confirm.ToLower() -eq "yes") {
                Write-Host "`nTriggering repairs..." -ForegroundColor Yellow
                $successCount = 0
                foreach ($torrent in $toRepair) {
                    $success = Invoke-TorrentRepair -Hash $torrent['Hash'] -Name $torrent['Name']
                    if ($success) {
                        $successCount++
                        
                        if ($torrent['Type'] -eq "Mismatch") {
                            $Script:Stats.CurrentMismatches = $Script:Stats.CurrentMismatches | Where-Object { $_['Hash'] -ne $torrent['Hash'] }
                            $Script:Stats.MismatchesCorrected++
                        }
                    }
                    Start-Sleep -Milliseconds 500
                }
                
                $Script:Stats.RepairsTriggered += $successCount
                
                Write-Host "`nRepair triggered for $successCount / $($toRepair.Count) torrent(s)" -ForegroundColor Green
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                Write-Host ""
                Write-Host "Refresh torrent list? (y/n): " -NoNewline -ForegroundColor Cyan
                $refreshChoice = Read-Host
                if ($refreshChoice.ToLower() -eq 'y') {
                    $newTorrents = Get-AllTorrentsForManagement -IncludeMismatches
                    if ($null -eq $newTorrents -or $newTorrents.Count -eq 0) {
                        Write-Host "No torrents found. Returning to monitoring." -ForegroundColor Green
                        Write-Host "Press any key..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        return
                    }
                    $Torrents = $newTorrents
                    $selected = @{}
                    for ($i = 0; $i -lt $Torrents.Count; $i++) {
                        $selected[$i] = $false
                    }
                }
            }
            else {
                Write-Host "Repair cancelled." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            }
        }
        
        elseif ($inputUpper -eq "D") {
            $toDelete = @()
            foreach ($idx in $visibleIndices) {
                if ($selected[$idx]) {
                    $toDelete += $Torrents[$idx]
                }
            }
            
            if ($toDelete.Count -eq 0) {
                Write-Host "`nNo torrents selected. Press any key to continue..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            
            Write-Host "`n" -NoNewline
            Write-Host "DANGER: " -ForegroundColor Red -NoNewline
            Write-Host "About to DELETE $($toDelete.Count) torrent(s). This cannot be undone!"
            Write-Host ""
            Write-Host "Torrents to be deleted:" -ForegroundColor Red
            foreach ($t in $toDelete) {
                Write-Host "  - [$($t['Type'])] $($t['Name'])" -ForegroundColor Yellow
            }
            Write-Host ""
            $confirm = Read-Host "Type 'DELETE' to confirm"
            
            if ($confirm -eq "DELETE") {
                Write-Host "`nDeleting torrents..." -ForegroundColor Red
                $successCount = 0
                foreach ($torrent in $toDelete) {
                    $success = Invoke-TorrentDelete -Hash $torrent['Hash'] -Name $torrent['Name']
                    if ($success) {
                        $successCount++
                        
                        if ($torrent['Type'] -eq "Mismatch") {
                            $Script:Stats.CurrentMismatches = $Script:Stats.CurrentMismatches | Where-Object { $_['Hash'] -ne $torrent['Hash'] }
                            $Script:Stats.MismatchesCorrected++
                        }
                    }
                    Start-Sleep -Milliseconds 500
                }
                
                $Script:Stats.DeletionsTriggered += $successCount
                
                Write-Host "`nDeleted $successCount / $($toDelete.Count) torrent(s)" -ForegroundColor Green
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                Write-Host ""
                Write-Host "Refresh torrent list? (y/n): " -NoNewline -ForegroundColor Cyan
                $refreshChoice = Read-Host
                if ($refreshChoice.ToLower() -eq 'y') {
                    $newTorrents = Get-AllTorrentsForManagement -IncludeMismatches
                    if ($null -eq $newTorrents -or $newTorrents.Count -eq 0) {
                        Write-Host "No torrents found. Returning to monitoring." -ForegroundColor Green
                        Write-Host "Press any key..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        return
                    }
                    $Torrents = $newTorrents
                    $selected = @{}
                    for ($i = 0; $i -lt $Torrents.Count; $i++) {
                        $selected[$i] = $false
                    }
                }
            }
            else {
                Write-Host "Deletion cancelled." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            }
        }
        
        elseif ($inputUpper -eq "L") {
            Write-Host "Refreshing torrent list..." -ForegroundColor Yellow
            $newTorrents = Get-AllTorrentsForManagement -IncludeMismatches
            if ($null -eq $newTorrents -or $newTorrents.Count -eq 0) {
                Write-Host "No torrents found. Returning to monitoring." -ForegroundColor Green
                Write-Host "Press any key..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }
            $Torrents = $newTorrents
            $selected = @{}
            for ($i = 0; $i -lt $Torrents.Count; $i++) {
                $selected[$i] = $false
            }
            Write-Host "List refreshed. Found $($Torrents.Count) torrent(s)." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        
        elseif ($inputUpper -eq "Q") {
            return
        }
        
        else {
            Write-Host "Invalid command. Press any key to continue..." -ForegroundColor Red
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# ============================================================================
# MAIN CHECK FUNCTION
# ============================================================================

function Start-BrokenTorrentCheck {
    Write-Log "" "INFO"
    Write-Log "Starting torrent status check..." "INFO"
    
    $Script:Stats.CurrentCheck = @{
        BrokenFound = 0
        UnderRepairFound = 0
        UnrepairableFound = 0
        RepairsTriggered = 0
        BrokenHashes = @()
        BrokenNames = @()
        UnderRepairHashes = @()
        UnderRepairNames = @()
        UnrepairableHashes = @()
        UnrepairableNames = @()
        UnrepairableReasons = @()
        VerifiedCount = 0
        MismatchCount = 0
    }
    
    # Get broken torrents
    $brokenTorrents = Get-ZurgTorrentsByState -State "status_broken"
    
    # Get under repair torrents
    $underRepairTorrents = Get-ZurgTorrentsByState -State "status_under_repair"
    
    # Get unrepairable torrents
    $unrepairableTorrents = Get-ZurgUnrepairableTorrents
    
    if ($null -eq $brokenTorrents -and $null -eq $underRepairTorrents -and $null -eq $unrepairableTorrents) {
        Write-Log "Failed to retrieve torrent status" "ERROR"
        $Script:Stats.TotalChecks++
        $Script:Stats.LastCheck = Get-Date
        return
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
    
    # Process unrepairable torrents
    if ($null -ne $unrepairableTorrents) {
        $Script:Stats.CurrentCheck.UnrepairableFound = $unrepairableTorrents.Count
        $Script:Stats.UnrepairableFound += $unrepairableTorrents.Count
    }
    
    Write-Log "Found $($Script:Stats.CurrentCheck.BrokenFound) broken torrent(s)" "INFO"
    Write-Log "Found $($Script:Stats.CurrentCheck.UnderRepairFound) under repair torrent(s)" "INFO"
    Write-Log "Found $($Script:Stats.CurrentCheck.UnrepairableFound) unrepairable torrent(s)" "INFO"
    
    # Display broken torrents
    if ($null -ne $brokenTorrents -and $brokenTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "BROKEN TORRENTS:" "WARN"
        foreach ($torrent in $brokenTorrents) {
            Write-Log "  - $($torrent['Name'])" "WARN"
            $Script:Stats.CurrentCheck.BrokenHashes += $torrent['Hash']
            $Script:Stats.CurrentCheck.BrokenNames += $torrent['Name']
        }
    }
    
    # Display under repair torrents
    if ($null -ne $underRepairTorrents -and $underRepairTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "UNDER REPAIR:" "INFO"
        foreach ($torrent in $underRepairTorrents) {
            Write-Log "  - $($torrent['Name'])" "INFO"
            $Script:Stats.CurrentCheck.UnderRepairHashes += $torrent['Hash']
            $Script:Stats.CurrentCheck.UnderRepairNames += $torrent['Name']
        }
    }
    
    # Display unrepairable torrents
    if ($null -ne $unrepairableTorrents -and $unrepairableTorrents.Count -gt 0) {
        Write-Log "" "INFO"
        Write-Log "UNREPAIRABLE TORRENTS:" "WARN"
        foreach ($torrent in $unrepairableTorrents) {
            Write-Log "  - $($torrent['Name'])" "WARN"
            Write-Log "    Reason: $($torrent['Reason'])" "WARN"
            $Script:Stats.CurrentCheck.UnrepairableHashes += $torrent['Hash']
            $Script:Stats.CurrentCheck.UnrepairableNames += $torrent['Name']
            $Script:Stats.CurrentCheck.UnrepairableReasons += $torrent['Reason']
        }
    }
    
    # Check if there's anything to repair
    if (($null -eq $brokenTorrents -or $brokenTorrents.Count -eq 0) -and 
        ($null -eq $underRepairTorrents -or $underRepairTorrents.Count -eq 0) -and
        ($null -eq $unrepairableTorrents -or $unrepairableTorrents.Count -eq 0)) {
        Write-Log "" "SUCCESS"
        Write-Log "No broken, under repair, or unrepairable torrents found - all good!" "SUCCESS"
    }
    
    Write-Log "" "INFO"
    
    # AutoRepair logic
    if ($Script:AutoRepairEnabled) {
        Write-Log "AutoRepair is ENABLED - triggering repairs..." "INFO"
        
        if ($null -ne $brokenTorrents -and $brokenTorrents.Count -gt 0) {
            foreach ($torrent in $brokenTorrents) {
                $success = Invoke-TorrentRepair -Hash $torrent['Hash'] -Name $torrent['Name']
                if ($success) {
                    $Script:Stats.CurrentCheck.RepairsTriggered++
                    $Script:Stats.RepairsTriggered++
                }
                Start-Sleep -Milliseconds 500
            }
        }
        
        if ($null -ne $underRepairTorrents -and $underRepairTorrents.Count -gt 0) {
            Write-Log "" "INFO"
            Write-Log "Re-triggering repairs for under repair torrents..." "INFO"
            foreach ($torrent in $underRepairTorrents) {
                $success = Invoke-TorrentRepair -Hash $torrent['Hash'] -Name $torrent['Name']
                if ($success) {
                    $Script:Stats.CurrentCheck.RepairsTriggered++
                    $Script:Stats.RepairsTriggered++
                }
                Start-Sleep -Milliseconds 500
            }
        }
    }
    else {
        Write-Log "AutoRepair is DISABLED - monitoring only mode" "INFO"
    }
    
    Write-Log "" "INFO"
    Write-Log "Torrent status check completed" "INFO"
    
    Show-CheckSummary -BrokenTorrents $brokenTorrents -UnderRepairTorrents $underRepairTorrents -UnrepairableTorrents $unrepairableTorrents
    
    # Save current as previous for next check
    $Script:Stats.PreviousCheck.BrokenHashes = $Script:Stats.CurrentCheck.BrokenHashes
    $Script:Stats.PreviousCheck.UnderRepairHashes = $Script:Stats.CurrentCheck.UnderRepairHashes
    $Script:Stats.PreviousCheck.TriggeredHashes = $Script:Stats.CurrentCheck.BrokenHashes + $Script:Stats.CurrentCheck.UnderRepairHashes
}

# ============================================================================
# STATISTICS & SUMMARY FUNCTIONS
# ============================================================================

function Show-Statistics {
    Write-Banner "OVERALL STATISTICS"
    
    $lastCheck = if ($Script:Stats.LastCheck) { $Script:Stats.LastCheck.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    $lastBroken = if ($Script:Stats.LastBrokenFound) { $Script:Stats.LastBrokenFound.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    $lastVerify = if ($Script:Stats.LastVerification) { $Script:Stats.LastVerification.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    
    Write-Host "MONITORING:" -ForegroundColor Yellow
    Write-Host "  Total Checks Performed:    $($Script:Stats.TotalChecks)" -ForegroundColor Cyan
    Write-Host "  Total Broken Found:        $($Script:Stats.BrokenFound)" -ForegroundColor Cyan
    Write-Host "  Total Under Repair Found:  $($Script:Stats.UnderRepairFound)" -ForegroundColor Cyan
    Write-Host "  Total Unrepairable Found:  $($Script:Stats.UnrepairableFound)" -ForegroundColor Cyan
    Write-Host "  Total Repairs Triggered:   $($Script:Stats.RepairsTriggered)" -ForegroundColor Cyan
    Write-Host "  Total Deletions Triggered: $($Script:Stats.DeletionsTriggered)" -ForegroundColor Cyan
    Write-Host "  Last Check:                $lastCheck" -ForegroundColor Cyan
    Write-Host "  Last Broken Found:         $lastBroken" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "VERIFICATION:" -ForegroundColor Yellow
    Write-Host "  Total Verifications Run:   $($Script:Stats.TotalVerifications)" -ForegroundColor Cyan
    Write-Host "  Torrents Verified:         $($Script:Stats.TorrentsVerified)" -ForegroundColor Cyan
    Write-Host "  Mismatches Found:          $($Script:Stats.MismatchesFound)" -ForegroundColor $(if ($Script:Stats.MismatchesFound -gt 0) { "Yellow" } else { "Cyan" })
    Write-Host "  Mismatches Corrected:      $($Script:Stats.MismatchesCorrected)" -ForegroundColor Cyan
    Write-Host "  Current Pending Mismatches:$($Script:Stats.CurrentMismatches.Count)" -ForegroundColor $(if ($Script:Stats.CurrentMismatches.Count -gt 0) { "Yellow" } else { "Cyan" })
    Write-Host "  Last Verification:         $lastVerify" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "STATUS:" -ForegroundColor Yellow
    $autoRepairStatus = if ($Script:AutoRepairEnabled) { "ENABLED" } else { "DISABLED" }
    $autoVerifyStatus = if ($Script:AutoVerifyEnabled) { "ENABLED (startup)" } else { "DISABLED" }
    Write-Host "  AutoRepair:                $autoRepairStatus" -ForegroundColor $(if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" })
    Write-Host "  AutoVerify:                $autoVerifyStatus" -ForegroundColor $(if ($Script:AutoVerifyEnabled) { "Green" } else { "Yellow" })
    Write-Host "  Settings File:             $(Get-SettingsPath)" -ForegroundColor Gray
    Write-Host "  Memory Usage:              $(Get-MemoryUsage) MB" -ForegroundColor Gray
}

function Show-CheckSummary {
    param(
        $BrokenTorrents,
        $UnderRepairTorrents,
        $UnrepairableTorrents
    )
    
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  CHECK SUMMARY" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CURRENT CHECK RESULTS:" -ForegroundColor Yellow
    Write-Host "  Broken Torrents:           $($Script:Stats.CurrentCheck.BrokenFound)" -ForegroundColor $(if ($Script:Stats.CurrentCheck.BrokenFound -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Under Repair:              $($Script:Stats.CurrentCheck.UnderRepairFound)" -ForegroundColor $(if ($Script:Stats.CurrentCheck.UnderRepairFound -gt 0) { "Cyan" } else { "Gray" })
    Write-Host "  Unrepairable:              $($Script:Stats.CurrentCheck.UnrepairableFound)" -ForegroundColor $(if ($Script:Stats.CurrentCheck.UnrepairableFound -gt 0) { "Red" } else { "Gray" })
    Write-Host "  Repairs Triggered:         $($Script:Stats.CurrentCheck.RepairsTriggered)" -ForegroundColor Green
    
    # Brief list of broken torrents
    if ($Script:Stats.CurrentCheck.BrokenNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Broken Torrents:" -ForegroundColor Yellow
        foreach ($name in $Script:Stats.CurrentCheck.BrokenNames) {
            Write-Host "    - $name" -ForegroundColor Yellow
        }
    }
    
    # Brief list of under repair torrents
    if ($Script:Stats.CurrentCheck.UnderRepairNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Under Repair:" -ForegroundColor Cyan
        foreach ($name in $Script:Stats.CurrentCheck.UnderRepairNames) {
            Write-Host "    - $name" -ForegroundColor Cyan
        }
    }
    
    # Brief list of unrepairable torrents
    if ($Script:Stats.CurrentCheck.UnrepairableNames.Count -gt 0) {
        Write-Host ""
        Write-Host "  Unrepairable:" -ForegroundColor Red
        for ($i = 0; $i -lt $Script:Stats.CurrentCheck.UnrepairableNames.Count; $i++) {
            Write-Host "    - $($Script:Stats.CurrentCheck.UnrepairableNames[$i])" -ForegroundColor Yellow
            Write-Host "      Reason: $($Script:Stats.CurrentCheck.UnrepairableReasons[$i])" -ForegroundColor DarkYellow
        }
    }
    
    # Show current mismatches if any
    if ($Script:Stats.CurrentMismatches.Count -gt 0) {
        Write-Host ""
        Write-Host "  Status Mismatches (Pending):" -ForegroundColor Magenta
        foreach ($mismatch in $Script:Stats.CurrentMismatches | Select-Object -First 5) {
            Write-Host "    - $($mismatch['Name'])" -ForegroundColor Magenta
            Write-Host "      Issue: $($mismatch['Reason'])" -ForegroundColor DarkMagenta
        }
        if ($Script:Stats.CurrentMismatches.Count -gt 5) {
            Write-Host "    ... and $($Script:Stats.CurrentMismatches.Count - 5) more" -ForegroundColor Gray
        }
    }
    
    # Comparison with previous check
    if ($Script:Stats.PreviousCheck.TriggeredHashes.Count -gt 0) {
        Write-Host ""
        Write-Host "COMPARISON WITH PREVIOUS CHECK:" -ForegroundColor Cyan
        
        $repairedCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.TriggeredHashes) {
            if (($Script:Stats.CurrentCheck.BrokenHashes -notcontains $hash) -and 
                ($Script:Stats.CurrentCheck.UnderRepairHashes -notcontains $hash)) {
                $repairedCount++
            }
        }
        
        $movedToRepairCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.BrokenHashes) {
            if ($Script:Stats.CurrentCheck.UnderRepairHashes -contains $hash) {
                $movedToRepairCount++
            }
        }
        
        $stillBrokenCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.BrokenHashes) {
            if ($Script:Stats.CurrentCheck.BrokenHashes -contains $hash) {
                $stillBrokenCount++
            }
        }
        
        $stillUnderRepairCount = 0
        foreach ($hash in $Script:Stats.PreviousCheck.UnderRepairHashes) {
            if ($Script:Stats.CurrentCheck.UnderRepairHashes -contains $hash) {
                $stillUnderRepairCount++
            }
        }
        
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
        
        if ($Script:Stats.PreviousCheck.TriggeredHashes.Count -gt 0) {
            $successRate = [math]::Round(($repairedCount / $Script:Stats.PreviousCheck.TriggeredHashes.Count) * 100, 1)
            Write-Host "  Repair Success Rate:       $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
        }
    }
    
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    
    # Offer management mode if there are any problem torrents
    $totalProblems = $Script:Stats.CurrentCheck.BrokenFound + $Script:Stats.CurrentCheck.UnderRepairFound + $Script:Stats.CurrentCheck.UnrepairableFound + $Script:Stats.CurrentMismatches.Count
    
    if ($totalProblems -gt 0) {
        Write-Host ""
        Write-Host "  Press 'M' to enter Management mode, or any other key to continue..." -ForegroundColor Cyan
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.Character -eq 'M' -or $key.Character -eq 'm') {
            $allTorrents = @()
            
            if ($null -ne $BrokenTorrents) {
                $allTorrents += $BrokenTorrents
            }
            if ($null -ne $UnderRepairTorrents) {
                $allTorrents += $UnderRepairTorrents
            }
            if ($null -ne $UnrepairableTorrents) {
                $allTorrents += $UnrepairableTorrents
            }
            foreach ($mismatch in $Script:Stats.CurrentMismatches) {
                $exists = $allTorrents | Where-Object { $_['Hash'] -eq $mismatch['Hash'] }
                if (-not $exists) {
                    $allTorrents += $mismatch
                }
            }
            
            Show-TorrentManagement -Torrents $allTorrents
        }
    }
    
    Write-Host ""
}

# ============================================================================
# MAIN MONITORING LOOP WITH COUNTDOWN TIMER
# ============================================================================

function Start-MonitoringLoop {
    Write-Banner "ZURG BROKEN TORRENT MONITOR v2.5.2"
    
    # Load saved settings
    Write-Log "Loading settings..." "INFO"
    if (Load-Settings) {
        Write-Log "Settings loaded from file" "SUCCESS"
    }
    else {
        Write-Log "Using default settings (AutoRepair: OFF, AutoVerify: OFF)" "INFO"
    }
    
    Write-Log "" "INFO"
    Write-Log "Starting Zurg Broken Torrent Monitor" "INFO"
    Write-Log "Zurg URL: $ZurgUrl" "INFO"
    Write-Log "Check Interval: $CheckIntervalMinutes minutes" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    Write-Log "Settings File: $(Get-SettingsPath)" "INFO"
    Write-Log "Authentication: $(if ($Username) { 'Enabled' } else { 'Disabled' })" "INFO"
    $repairMode = if ($Script:AutoRepairEnabled) { "ENABLED" } else { "DISABLED" }
    Write-Log "Auto-Repair: $repairMode" "INFO"
    $verifyMode = if ($Script:AutoVerifyEnabled) { "ENABLED (runs on startup)" } else { "DISABLED" }
    Write-Log "Auto-Verify: $verifyMode" "INFO"
    Write-Log "" "INFO"
    
    if (-not (Test-ZurgConnection)) {
        Write-Log "Cannot connect to Zurg - exiting" "ERROR"
        return
    }
    
    Write-Log "" "INFO"
    
    # Run startup verification if enabled and not skipped
    if ($Script:AutoVerifyEnabled -and -not $SkipStartupVerification) {
        Write-Log "Running startup health verification..." "INFO"
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host "  STARTUP HEALTH VERIFICATION" -ForegroundColor Magenta
        Write-Host "  (Disable with -SkipStartupVerification or toggle AutoVerify OFF)" -ForegroundColor DarkMagenta
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host ""
        
        $verifyResult = Invoke-HealthVerification
        
        if ($verifyResult.Mismatches.Count -gt 0) {
            Write-Host ""
            Write-Host "Press 'M' to manage mismatches now, or any key to continue to monitoring..." -ForegroundColor Cyan
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($key.Character -eq 'M' -or $key.Character -eq 'm') {
                $allTorrents = Get-AllTorrentsForManagement -IncludeMismatches
                if ($null -ne $allTorrents -and $allTorrents.Count -gt 0) {
                    Show-TorrentManagement -Torrents $allTorrents
                }
            }
        }
        else {
            Write-Host "Press any key to continue to monitoring..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        Write-Host ""
    }
    elseif ($SkipStartupVerification) {
        Write-Log "Startup verification skipped (command-line flag)" "INFO"
    }
    
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
            
            # Memory cleanup after each check cycle
            $null = Invoke-MemoryCleanup -Silent
            
            Write-Log "" "INFO"
            
            # Wait with live countdown timer
            $waitSeconds = $CheckIntervalMinutes * 60
            $endTime = (Get-Date).AddSeconds($waitSeconds)
            $startWait = Get-Date
            
            Write-Host ""
            Write-Host "======================================================================" -ForegroundColor DarkGray
            Write-Host "  WAITING FOR NEXT CHECK                              Mem: $(Get-MemoryUsage) MB" -ForegroundColor DarkGray
            Write-Host "  Press: [M] Management  [S] Stats  [V] Health Verify  [Ctrl+C] Exit" -ForegroundColor DarkGray
            Write-Host "======================================================================" -ForegroundColor DarkGray
            Write-Host ""
            
            $lastUpdate = Get-Date
            
            while ((Get-Date) -lt $endTime) {
                # Check for keypress (non-blocking)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    # Clear the countdown line
                    Write-Host "`r" + (" " * 80) + "`r" -NoNewline
                    
                    if ($key.Key -eq 'M') {
                        Write-Host ""
                        Write-Host "Entering Management Mode..." -ForegroundColor Cyan
                        $allTorrents = Get-AllTorrentsForManagement -IncludeMismatches
                        if ($null -ne $allTorrents -and $allTorrents.Count -gt 0) {
                            Show-TorrentManagement -Torrents $allTorrents
                        }
                        else {
                            Write-Host "No problem torrents found to manage." -ForegroundColor Green
                            Write-Host "Press any key to continue..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        
                        # Memory cleanup after management
                        $null = Invoke-MemoryCleanup -Silent
                        
                        # Re-display wait header only if time remains
                        $remaining = $endTime - (Get-Date)
                        if ($remaining.TotalSeconds -gt 0) {
                            Write-Host ""
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host "  WAITING FOR NEXT CHECK                              Mem: $(Get-MemoryUsage) MB" -ForegroundColor DarkGray
                            Write-Host "  Press: [M] Management  [S] Stats  [V] Health Verify  [Ctrl+C] Exit" -ForegroundColor DarkGray
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host ""
                        }
                        else {
                            # Time expired while in management, continue to next check
                            break
                        }
                    }
                    elseif ($key.Key -eq 'S') {
                        Write-Host ""
                        Show-Statistics
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        
                        # Re-display wait header only if time remains
                        $remaining = $endTime - (Get-Date)
                        if ($remaining.TotalSeconds -gt 0) {
                            Write-Host ""
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host "  WAITING FOR NEXT CHECK                              Mem: $(Get-MemoryUsage) MB" -ForegroundColor DarkGray
                            Write-Host "  Press: [M] Management  [S] Stats  [V] Health Verify  [Ctrl+C] Exit" -ForegroundColor DarkGray
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host ""
                        }
                        else {
                            # Time expired, continue to next check
                            break
                        }
                    }
                    elseif ($key.Key -eq 'V') {
                        Write-Host ""
                        $result = Invoke-HealthVerification
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        
                        # Re-display wait header only if time remains
                        $remaining = $endTime - (Get-Date)
                        if ($remaining.TotalSeconds -gt 0) {
                            Write-Host ""
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host "  WAITING FOR NEXT CHECK                              Mem: $(Get-MemoryUsage) MB" -ForegroundColor DarkGray
                            Write-Host "  Press: [M] Management  [S] Stats  [V] Health Verify  [Ctrl+C] Exit" -ForegroundColor DarkGray
                            Write-Host "======================================================================" -ForegroundColor DarkGray
                            Write-Host ""
                        }
                        else {
                            # Time expired, continue to next check
                            break
                        }
                    }
                    else {
                        # Unrecognized key - check if wait time expired
                        $remaining = $endTime - (Get-Date)
                        if ($remaining.TotalSeconds -le 0) {
                            # Time expired, continue to next check
                            break
                        }
                        # Otherwise just ignore the key and continue waiting
                    }
                }
                
                # Update countdown display every second
                $now = Get-Date
                if (($now - $lastUpdate).TotalMilliseconds -ge 1000) {
                    $remaining = $endTime - $now
                    $elapsed = $now - $startWait
                    
                    # Check if we've exceeded the wait time (shouldn't happen but just in case)
                    if ($remaining.TotalSeconds -le 0) {
                        break  # Exit the wait loop
                    }
                    
                    # Build countdown display
                    $countdownText = Format-TimeSpan $remaining
                    $nextCheckTime = $endTime.ToString("HH:mm:ss")
                    
                    # Progress bar for wait time (with bounds checking)
                    $waitProgress = 1 - ($remaining.TotalSeconds / $waitSeconds)
                    $waitProgress = [Math]::Max(0, [Math]::Min(1, $waitProgress))  # Clamp to 0-1
                    $barWidth = 20
                    $filledWidth = [math]::Floor($waitProgress * $barWidth)
                    $filledWidth = [Math]::Max(0, [Math]::Min($barWidth, $filledWidth))  # Clamp to 0-barWidth
                    $emptyWidth = $barWidth - $filledWidth
                    $progressBar = ("█" * $filledWidth) + ("░" * $emptyWidth)
                    
                    $statusLine = "`r  [$progressBar] Next check in: $countdownText (at $nextCheckTime)    "
                    Write-Host $statusLine -NoNewline -ForegroundColor Yellow
                    
                    $lastUpdate = $now
                }
                
                Start-Sleep -Milliseconds 100
            }
            
            Write-Host ""  # New line after countdown
            Write-Host ""
            Write-Log "======================================================================" "INFO"
            Write-Log "" "INFO"
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

# ============================================================================
# ENTRY POINT
# ============================================================================

if ($CheckIntervalMinutes -lt 1) {
    Write-Host "Error: CheckIntervalMinutes must be at least 1" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
}

Add-Type -AssemblyName System.Web

Start-MonitoringLoop
