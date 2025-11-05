# Zurg Broken Torrent Monitor - Configuration Examples

## Basic Configuration

The script uses these default values:

```powershell
$ZurgUrl = "http://localhost:9999"
$Username = "riven"
$Password = "12345"
$CheckIntervalMinutes = 30
$LogFile = "zurg-broken-torrent-monitor.log"
```

## Configuration Methods

### Method 1: Edit the Script

Open `Zurg-Broken-Torrent-Monitor.ps1` and edit the param block at the top:

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$ZurgUrl = "http://192.168.1.100:9999",  # Change this
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "myuser",  # Change this
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "mypass",  # Change this
    
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalMinutes = 15,  # Change this
)
```

### Method 2: Command Line Arguments (Recommended)

Pass parameters when running:

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 `
    -ZurgUrl "http://192.168.1.100:9999" `
    -Username "myuser" `
    -Password "mypass" `
    -CheckIntervalMinutes 15
```

## Common Configurations

### 1. Remote Zurg Server

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 `
    -ZurgUrl "http://192.168.1.50:9999" `
    -Username "admin" `
    -Password "secure-password"
```

### 2. Aggressive Monitoring (5 minutes)

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 5
```

### 3. Conservative Monitoring (60 minutes)

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 60
```

### 4. Custom Log Location

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 `
    -LogFile "C:\Logs\zurg-monitor.log"
```

### 5. Verbose Debugging

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -VerboseLogging
```

### 6. Single Test Run

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

## Windows Service Configuration (NSSM)

### Install Service with Custom Settings

```powershell
nssm install ZurgMonitor powershell.exe `
  "-ExecutionPolicy Bypass -NoProfile -File C:\Scripts\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl http://192.168.1.100:9999 -Username admin -Password mypassword -CheckIntervalMinutes 15"
```

### Service Settings

```powershell
# Set startup type
nssm set ZurgMonitor Start SERVICE_AUTO_START

# Set display name
nssm set ZurgMonitor DisplayName "Zurg Broken Torrent Monitor"

# Set description
nssm set ZurgMonitor Description "Automatically monitors and repairs broken torrents in Zurg"

# Configure failure actions
nssm set ZurgMonitor AppRestartDelay 60000  # Restart after 60 seconds if it crashes
```

## Task Scheduler Configuration

### Create Scheduled Task

1. **General Tab:**
   - Name: `Zurg Broken Torrent Monitor`
   - Description: `Monitors Zurg for broken torrents and triggers repairs`
   - Run whether user is logged on or not: ✓
   - Run with highest privileges: ✓

2. **Triggers Tab:**
   - Begin the task: `At startup`
   - Advanced settings:
     - Repeat task every: `30 minutes`
     - For a duration of: `Indefinitely`
     - Stop task if it runs longer than: `30 minutes`

3. **Actions Tab:**
   - Action: `Start a program`
   - Program/script: `powershell.exe`
   - Arguments:
     ```
     -ExecutionPolicy Bypass -NoProfile -File "C:\Scripts\Zurg-Broken-Torrent-Monitor.ps1" -ZurgUrl "http://localhost:9999" -Username "riven" -Password "12345" -CheckIntervalMinutes 30
     ```

4. **Conditions Tab:**
   - Start only if computer is on AC power: ✗
   - Wake the computer to run this task: ✗

5. **Settings Tab:**
   - Allow task to be run on demand: ✓
   - Stop the task if it runs longer than: `1 hour`
   - If the task is already running: `Do not start a new instance`

## Recommended Check Intervals

| Scenario | Interval | Reason |
|----------|----------|--------|
| **Critical Production** | 5-10 min | Immediate repair response |
| **Standard Home Setup** | 15-30 min | Balanced monitoring |
| **Stable Library** | 60+ min | Less frequent issues |
| **Testing/Development** | 5 min | Quick feedback |

## Security Notes

### Credentials in Command Line

When using Task Scheduler or NSSM, credentials may be visible in task properties. Consider:

1. **Use Windows Credential Manager** (future enhancement)
2. **Restrict task permissions** - Only administrators can view
3. **Use a dedicated Zurg account** with limited permissions

### Network Security

- Use HTTPS if Zurg supports it
- Consider VPN if accessing Zurg remotely
- Use strong passwords for Zurg authentication

## Troubleshooting Configuration

### Test Configuration

```powershell
# Test connection
curl http://localhost:9999/stats

# Test with authentication
$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("riven:12345"))
}
curl http://localhost:9999/stats -Headers $headers

# Test single run
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce -VerboseLogging
```

### Common Issues

**Wrong credentials:**
- Error: `401 Unauthorized`
- Fix: Check `config.yml` in Zurg

**Wrong URL:**
- Error: `Failed to connect`
- Fix: Verify Zurg is running and URL is correct

**Port blocked:**
- Error: `Connection refused`
- Fix: Check firewall settings

## Advanced Configuration

### Multiple Zurg Instances

Create separate scripts with different configurations:

```powershell
# zurg1-monitor.bat
powershell -ExecutionPolicy Bypass -File .\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://server1:9999" -LogFile "zurg1.log"

# zurg2-monitor.bat
powershell -ExecutionPolicy Bypass -File .\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://server2:9999" -LogFile "zurg2.log"
```

### Log Rotation

Use Windows Task Scheduler to rotate logs:

```powershell
# rotate-logs.ps1
$logFile = "zurg-broken-torrent-monitor.log"
$archiveFile = "zurg-monitor-$(Get-Date -Format 'yyyy-MM-dd').log"

if (Test-Path $logFile) {
    Move-Item $logFile $archiveFile
}

# Keep only last 30 days
Get-ChildItem "zurg-monitor-*.log" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item
```

Schedule this to run daily at midnight.
