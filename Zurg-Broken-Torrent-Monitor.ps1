# ============================================================================
# Zurg Broken Torrent Monitor & Repair Tool v2.4.0
# ============================================================================
# New in v2.4.0:
#   - Unified Management UI for ALL torrent types (Broken, Under Repair, Unrepairable)
#   - Search/Filter by name, state, or reason
#   - Bulk actions by reason (select all matching)
#   - Toggle AutoRepair on/off from within Management UI
#   - Statistics tracking for all manual actions
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
    [switch]$VerboseLogging,
    
    [Parameter(Mandatory=$false)]
    [bool]$AutoRepair = $false
)

$ErrorActionPreference = "Continue"

# Make AutoRepair a script-level variable so it can be toggled at runtime
$Script:AutoRepairEnabled = $AutoRepair

$Script:Stats = @{
    TotalChecks = 0
    BrokenFound = 0
    UnderRepairFound = 0
    UnrepairableFound = 0
    RepairsTriggered = 0
    DeletionsTriggered = 0
    LastCheck = $null
    LastBrokenFound = $null
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
                    Type = if ($State -eq "status_broken") { "Broken" } else { "Under Repair" }
                    Reason = ""
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
                    Type = if ($State -eq "status_broken") { "Broken" } else { "Under Repair" }
                    Reason = ""
                }
            }
        }
        
        Write-Log "Successfully parsed $($torrents.Count) $stateName torrent(s)" "DEBUG"
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
# UNIFIED TORRENT MANAGEMENT UI (v2.4.0)
# ============================================================================

function Get-AllTorrentsForManagement {
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
    $filterState = "*"  # B=Broken, U=Under Repair, C=Cannot Repair, *=All
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
        
        # Header
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host "  TORRENT MANAGEMENT CENTER v2.4.0" -ForegroundColor Magenta
        Write-Host "======================================================================" -ForegroundColor Magenta
        Write-Host ""
        
        # Summary line
        Write-Host "Total: $($Torrents.Count) torrents  |  " -NoNewline -ForegroundColor White
        Write-Host "Broken: $brokenCount" -NoNewline -ForegroundColor Yellow
        Write-Host "  |  " -NoNewline -ForegroundColor White
        Write-Host "Under Repair: $underRepairCount" -NoNewline -ForegroundColor Cyan
        Write-Host "  |  " -NoNewline -ForegroundColor White
        Write-Host "Unrepairable: $unrepairableCount" -ForegroundColor Red
        Write-Host ""
        
        # AutoRepair status
        $autoRepairStatus = if ($Script:AutoRepairEnabled) { "ON" } else { "OFF" }
        $autoRepairColor = if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" }
        Write-Host "AutoRepair: " -NoNewline -ForegroundColor Gray
        Write-Host $autoRepairStatus -ForegroundColor $autoRepairColor
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
                    default { "White" }
                }
                $typeBadge = switch ($torrent['Type']) {
                    "Broken" { "[BRK]" }
                    "Under Repair" { "[REP]" }
                    "Unrepairable" { "[BAD]" }
                    default { "[???]" }
                }
                
                Write-Host "$number. $checkbox " -NoNewline
                Write-Host $typeBadge -NoNewline -ForegroundColor $typeColor
                Write-Host " $($torrent['Name'])" -ForegroundColor White
                
                # Show reason for unrepairable torrents
                if ($torrent['Type'] -eq "Unrepairable" -and $torrent['Reason'] -ne "") {
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
        Write-Host "  [F*] Show All        [FS] Search by name        [FR] Filter by reason" -ForegroundColor White
        Write-Host "  [FX] Clear all filters" -ForegroundColor White
        Write-Host ""
        Write-Host "BULK BY REASON:" -ForegroundColor Yellow
        Write-Host "  [BR] Select all matching a reason (e.g., 'infringing', 'not cached')" -ForegroundColor White
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
        
        # Filter Broken
        elseif ($inputUpper -eq "FB") {
            $filterState = "B"
        }
        # Filter Under Repair
        elseif ($inputUpper -eq "FU") {
            $filterState = "U"
        }
        # Filter Unrepairable (Cannot Repair)
        elseif ($inputUpper -eq "FC") {
            $filterState = "C"
        }
        # Show All (clear state filter)
        elseif ($inputUpper -eq "F*") {
            $filterState = "*"
        }
        # Search by name
        elseif ($inputUpper -eq "FS") {
            Write-Host ""
            $searchText = Read-Host "Enter search text (blank to clear)"
        }
        # Filter by reason
        elseif ($inputUpper -eq "FR") {
            Write-Host ""
            Write-Host "Common reasons: infringing, not cached, download status: error, invalid file ids" -ForegroundColor Gray
            $reasonFilter = Read-Host "Enter reason filter (blank to clear)"
        }
        # Clear all filters
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
        
        # ==================== ACTION COMMANDS ====================
        
        # Toggle AutoRepair
        elseif ($inputUpper -eq "T") {
            $Script:AutoRepairEnabled = -not $Script:AutoRepairEnabled
            $status = if ($Script:AutoRepairEnabled) { "ENABLED" } else { "DISABLED" }
            Write-Host ""
            Write-Host "AutoRepair is now $status" -ForegroundColor $(if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" })
            Write-Log "AutoRepair toggled to $status via Management UI" "INFO"
            Start-Sleep -Seconds 1
        }
        
        # Repair selected
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
                    }
                    Start-Sleep -Milliseconds 500
                }
                
                $Script:Stats.RepairsTriggered += $successCount
                
                Write-Host "`nRepair triggered for $successCount / $($toRepair.Count) torrent(s)" -ForegroundColor Green
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                # Prompt to refresh
                Write-Host ""
                Write-Host "Refresh torrent list? (y/n): " -NoNewline -ForegroundColor Cyan
                $refreshChoice = Read-Host
                if ($refreshChoice.ToLower() -eq 'y') {
                    $newTorrents = Get-AllTorrentsForManagement
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
        
        # Delete selected
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
                    }
                    Start-Sleep -Milliseconds 500
                }
                
                $Script:Stats.DeletionsTriggered += $successCount
                
                Write-Host "`nDeleted $successCount / $($toDelete.Count) torrent(s)" -ForegroundColor Green
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                # Prompt to refresh
                Write-Host ""
                Write-Host "Refresh torrent list? (y/n): " -NoNewline -ForegroundColor Cyan
                $refreshChoice = Read-Host
                if ($refreshChoice.ToLower() -eq 'y') {
                    $newTorrents = Get-AllTorrentsForManagement
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
        
        # Refresh list
        elseif ($inputUpper -eq "L") {
            Write-Host "Refreshing torrent list..." -ForegroundColor Yellow
            $newTorrents = Get-AllTorrentsForManagement
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
        
        # Quit
        elseif ($inputUpper -eq "Q") {
            return
        }
        
        # Invalid command
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
        
        # Trigger repair for broken torrents
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
        
        # Trigger repair for under repair torrents (re-trigger to help them along)
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
    
    Write-Host "Total Checks Performed:    $($Script:Stats.TotalChecks)" -ForegroundColor Cyan
    Write-Host "Total Broken Found:        $($Script:Stats.BrokenFound)" -ForegroundColor Cyan
    Write-Host "Total Under Repair Found:  $($Script:Stats.UnderRepairFound)" -ForegroundColor Cyan
    Write-Host "Total Unrepairable Found:  $($Script:Stats.UnrepairableFound)" -ForegroundColor Cyan
    Write-Host "Total Repairs Triggered:   $($Script:Stats.RepairsTriggered)" -ForegroundColor Cyan
    Write-Host "Total Deletions Triggered: $($Script:Stats.DeletionsTriggered)" -ForegroundColor Cyan
    Write-Host "Last Check:                $lastCheck" -ForegroundColor Cyan
    Write-Host "Last Broken Found:         $lastBroken" -ForegroundColor Cyan
    Write-Host ""
    $autoStatus = if ($Script:AutoRepairEnabled) { "ENABLED" } else { "DISABLED" }
    Write-Host "AutoRepair Status:         $autoStatus" -ForegroundColor $(if ($Script:AutoRepairEnabled) { "Green" } else { "Yellow" })
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
    $totalProblems = $Script:Stats.CurrentCheck.BrokenFound + $Script:Stats.CurrentCheck.UnderRepairFound + $Script:Stats.CurrentCheck.UnrepairableFound
    
    if ($totalProblems -gt 0) {
        Write-Host ""
        Write-Host "  Press 'M' to enter Management mode, or any other key to continue..." -ForegroundColor Cyan
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.Character -eq 'M' -or $key.Character -eq 'm') {
            # Build combined torrent list for management
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
            
            Show-TorrentManagement -Torrents $allTorrents
        }
    }
    
    Write-Host ""
}

# ============================================================================
# MAIN MONITORING LOOP
# ============================================================================

function Start-MonitoringLoop {
    Write-Banner "ZURG BROKEN TORRENT MONITOR v2.4.0"
    
    Write-Log "Starting Zurg Broken Torrent Monitor" "INFO"
    Write-Log "Zurg URL: $ZurgUrl" "INFO"
    Write-Log "Check Interval: $CheckIntervalMinutes minutes" "INFO"
    Write-Log "Log File: $LogFile" "INFO"
    Write-Log "Authentication: $(if ($Username) { 'Enabled' } else { 'Disabled' })" "INFO"
    $repairMode = if (-not $Script:AutoRepairEnabled) { "Disabled (Monitoring Only)" } else { "Enabled" }
    Write-Log "Auto-Repair: $repairMode" "INFO"
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
            Write-Log "Next check in $CheckIntervalMinutes minutes... (Press 'M' for Management, 'S' for Stats)" "INFO"
            Write-Log "======================================================================" "INFO"
            Write-Log "" "INFO"
            
            # Wait with keypress detection
            $waitSeconds = $CheckIntervalMinutes * 60
            $endTime = (Get-Date).AddSeconds($waitSeconds)
            
            while ((Get-Date) -lt $endTime) {
                # Check for keypress (non-blocking)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    if ($key.Key -eq 'M') {
                        Write-Host ""
                        Write-Host "Entering Management Mode..." -ForegroundColor Cyan
                        $allTorrents = Get-AllTorrentsForManagement
                        if ($null -ne $allTorrents -and $allTorrents.Count -gt 0) {
                            Show-TorrentManagement -Torrents $allTorrents
                        }
                        else {
                            Write-Host "No problem torrents found to manage." -ForegroundColor Green
                            Write-Host "Press any key to continue..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        
                        # After returning from management, show remaining time
                        $remaining = ($endTime - (Get-Date)).TotalMinutes
                        if ($remaining -gt 0) {
                            Write-Log "" "INFO"
                            Write-Log "Returned to monitoring. Next check in $([math]::Round($remaining, 1)) minutes... (Press 'M' for Management, 'S' for Stats)" "INFO"
                        }
                    }
                    elseif ($key.Key -eq 'S') {
                        Write-Host ""
                        Show-Statistics
                        Write-Host ""
                        $remaining = ($endTime - (Get-Date)).TotalMinutes
                        if ($remaining -gt 0) {
                            Write-Log "Next check in $([math]::Round($remaining, 1)) minutes... (Press 'M' for Management, 'S' for Stats)" "INFO"
                        }
                    }
                }
                
                Start-Sleep -Milliseconds 250
            }
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
