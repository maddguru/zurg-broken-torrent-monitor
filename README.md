# Zurg Broken Torrent Monitor

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

A PowerShell script that continuously monitors [Zurg](https://github.com/debridmediamanager/zurg-testing) for broken torrents and automatically triggers repairs. This ensures your Plex/Jellyfin/Emby library stays healthy without manual intervention.

## ✨ Features

- 🔍 **Automatic Detection** - Monitors Zurg for broken torrents using its native state filtering
- 🔧 **Auto-Repair** - Automatically triggers repair for all broken torrents via Zurg's API
- 📊 **Progress Tracking** - Shows repair success rates and comparisons between checks
- 📝 **Comprehensive Logging** - Detailed logs with timestamps for troubleshooting
- ⚙️ **Configurable** - Adjust check intervals, credentials, and other settings
- 🎨 **Color-Coded Output** - Easy-to-read console output with status colors

## 📋 Requirements

- **PowerShell 5.1 or higher** (included with Windows 10/11)
- **Zurg** - Must be running and accessible
- **Network Access** - Script must be able to reach Zurg's API

## 🚀 Quick Start

### 1. Download

Download `Zurg-Broken-Torrent-Monitor.ps1` from the [latest release](https://github.com/maddguru/zurg-broken-torrent-monitor/releases).

### 2. Configure (Optional)

Edit the script parameters at the top, or pass them via command line:

```powershell
# Default settings
$ZurgUrl = "http://localhost:9999"
$Username = "riven"
$Password = "12345"
$CheckIntervalMinutes = 30
```

### 3. Run

**Test it once:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

**Run continuously:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1
```

**Custom interval (every 15 minutes):**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 15
```

## 📖 Usage

### Command Line Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ZurgUrl` | String | `http://localhost:9999` | Zurg server URL |
| `-Username` | String | `riven` | Zurg basic auth username |
| `-Password` | String | `12345` | Zurg basic auth password |
| `-CheckIntervalMinutes` | Int | `30` | Minutes between checks |
| `-LogFile` | String | `zurg-broken-torrent-monitor.log` | Log file path |
| `-RunOnce` | Switch | Off | Run once and exit |
| `-VerboseLogging` | Switch | Off | Enable debug output |

### Examples

**Basic usage with defaults:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1
```

**Custom Zurg URL:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://192.168.1.100:9999"
```

**Check every 5 minutes with verbose logging:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 5 -VerboseLogging
```

**Single check (useful for testing):**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

## 📊 Sample Output

```
========================================================================
  ZURG BROKEN TORRENT MONITOR v2.0
========================================================================

[2025-10-31 17:21:13] [INFO] Starting Zurg Broken Torrent Monitor
[2025-10-31 17:21:13] [SUCCESS] Successfully connected to Zurg
[2025-10-31 17:21:14] [INFO] Found 8 broken torrent(s)
[2025-10-31 17:21:14] [WARN]   Found broken torrent: Show.Name.S01.1080p
[2025-10-31 17:21:15] [SUCCESS] Successfully triggered repair for: Show.Name.S01.1080p

======================================================================
  CHECK SUMMARY
======================================================================

CURRENT CHECK RESULTS:
  Broken Torrents Found:     8
  Repairs Triggered:         8

  Broken Torrents:
    - Show.Name.S01.1080p
    - Movie.Title.2024.1080p
    - Another.Show.S02.720p

COMPARISON WITH PREVIOUS CHECK:
  Successfully Repaired:     2
  Still Broken (from prev):  6
  New Broken (not in prev):  0
  Repair Success Rate:       25.0%

======================================================================
```

## 🔧 Running as a Service

### Option 1: Windows Task Scheduler

1. Open Task Scheduler (`taskschd.msc`)
2. Create Task → General tab:
   - Name: `Zurg Broken Torrent Monitor`
   - Run whether user is logged on or not
3. Triggers tab → New:
   - Begin: `At startup`
   - Advanced: Repeat every 30 minutes
4. Actions tab → New:
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -NoProfile -File "C:\Path\To\Zurg-Broken-Torrent-Monitor.ps1"`

### Option 2: NSSM (Recommended)

Download [NSSM](https://nssm.cc/download) and install as a service:

```powershell
# Install service
nssm install ZurgMonitor "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
  "-ExecutionPolicy Bypass -NoProfile -File C:\Path\To\Zurg-Broken-Torrent-Monitor.ps1"

# Set to start automatically
nssm set ZurgMonitor Start SERVICE_AUTO_START

# Start the service
nssm start ZurgMonitor
```

**Manage the service:**
```powershell
nssm status ZurgMonitor   # Check status
nssm stop ZurgMonitor     # Stop service
nssm start ZurgMonitor    # Start service
nssm remove ZurgMonitor   # Remove service
```

## 🐛 Troubleshooting

### Connection Failed

**Error:** `Failed to connect to Zurg`

**Solutions:**
- Verify Zurg is running: `curl http://localhost:9999/stats`
- Check firewall settings
- Verify the URL is correct (include `http://`)

### Authentication Failed

**Error:** `401 Unauthorized`

**Solutions:**
- Check username/password match your `config.yml`
- Verify credentials are correct (default: `riven` / `12345`)

### Execution Policy Error

**Error:** `cannot be loaded because running scripts is disabled`

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script Finds Different Torrents Than Web UI

This shouldn't happen! The script fetches the exact same filtered page as the web interface. If you see this:
1. Enable verbose logging: `-VerboseLogging`
2. Check the log file for details
3. Open an issue with the log output

## 📁 Log Files

Logs are saved to `zurg-broken-torrent-monitor.log` by default. The log includes:
- All detected broken torrents
- Repair attempts and results
- Statistics and comparisons
- Error messages for troubleshooting

View recent logs:
```powershell
Get-Content zurg-broken-torrent-monitor.log -Tail 50
```

## 🔄 How It Works

1. **Fetch Broken Torrents** - Queries Zurg's `/manage/?state=status_broken` endpoint
2. **Extract Names** - Parses HTML to get torrent hashes and names
3. **Trigger Repairs** - Calls `/manage/{hash}/repair` for each broken torrent
4. **Track Progress** - Compares with previous check to show repair success rate
5. **Repeat** - Waits for configured interval and starts again

This ensures the script finds **exactly the same torrents** as Zurg's web interface.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Zurg](https://github.com/debridmediamanager/zurg-testing) - The amazing tool this script monitors
- All contributors and users who provide feedback

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/maddguru/zurg-broken-torrent-monitor/issues)
- **Discussions:** [GitHub Discussions](https://github.com/maddguru/zurg-broken-torrent-monitor/discussions)

## ⭐ Star History

If you find this useful, please consider giving it a star! ⭐

---

**Note:** This script is not affiliated with or endorsed by Zurg or Debrid Media Manager. It's a community tool to help automate torrent maintenance.
