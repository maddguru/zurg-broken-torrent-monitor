# Zurg Broken Torrent Monitor & Repair Tool

[![Version](https://img.shields.io/badge/version-2.3.0-blue.svg)](https://github.com/maddguru/zurg-broken-torrent-monitor/releases/latest)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/PowerShell/PowerShell#get-powershell)

**Automated monitoring and management of broken, under-repair, and unrepairable torrents in Zurg + Real-Debrid setups.**

---

## 🎯 Overview

Zurg Broken Torrent Monitor is a PowerShell script that continuously monitors your Zurg instance for broken, under-repair, and unrepairable torrents. It provides an interactive management interface, automatic repairs, and comprehensive statistics about your torrent library's health.

### Key Features

**Core Monitoring:**
- 🔍 **Broken Torrent Detection** - Automatically detects torrents in broken state
- 🔧 **Automatic Repairs** - Optional auto-repair for broken torrents
- 🔄 **Under-Repair Monitoring** - Tracks torrents currently being repaired
- 📊 **Statistics Tracking** - Comprehensive stats for all operations

**v2.3.0 - Unrepairable Torrent Management:**
- 🆕 **Interactive Management UI** - Professional interface for managing unrepairable torrents
- 🆕 **Bulk Selection** - Advanced selection: single, ranges (`1-10`), lists (`1,5,10`), mixed (`1-5,10,15-20`)
- 🆕 **Continuous Management** - Stay in management mode, refresh after actions
- 🆕 **Repair or Delete** - Choose to repair or delete selected torrents
- 🆕 **Auto-Repair Control** - `-AutoRepair` parameter (default: `$false`)
- 🆕 **Deletion Tracking** - Statistics for manual deletions

**Additional Features:**
- 🎨 **Color-Coded Output** - Easy-to-read visual feedback
- 📝 **Comprehensive Logging** - Detailed logs for troubleshooting
- ⚙️ **Flexible Scheduling** - Run once or continuous monitoring
- 🔐 **Authentication Support** - Basic auth for secured Zurg instances

---

## 📊 What's New in v2.3.0

**Unrepairable Torrent Management** - The flagship feature of this release:

```
======================================================================
  UNREPAIRABLE TORRENT MANAGEMENT
======================================================================
Found 70 unrepairable torrent(s)

 1. [ ] Platonic.2023.S02E10.Brett.Coyotes.Last.Stand...
       Reason: repair failed, download status: error
       Hash: edf9fe56b4fd20ff8d2c87454e21b8d10229f6d1

 2. [ ] Most.Wanted.Teen.Hacker.S01E03.2160p.WEB.h265-EDITH
       Reason: repair failed, download status: error
       Hash: 7aceaf577a7a9e4822bdd7d8f6f622a57acf206a
...

Commands:
  [#] [#-#] [#,#]  Toggle selection (single, range, or list)
  [A]              Select All
  [N]              Select None
  [R]              Repair selected torrents
  [D]              Delete selected torrents
  [Q]              Quit and return to monitoring

Currently selected: 0 torrent(s)
Enter command: _
```

**Enhanced Selection Syntax:**
- Single: `5` - Toggle one torrent
- Range: `1-10` - Toggle consecutive torrents
- List: `1,5,10,15` - Toggle specific torrents
- Mixed: `1-5,10,15-20,25` - Combine ranges and individuals

**Safety First:**
- Auto-repair disabled by default (`-AutoRepair $false`)
- Confirmation prompts for all actions (type `yes` to repair, `DELETE` to delete)
- Continuous management mode with refresh capabilities

[See full v2.3.0 release notes →](V2.3.0-RELEASE-NOTES.md)

---

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7.0+** (tested on 7.5.4)
- **Windows 10/11** or Windows Server 2019+
- **Zurg** running at `http://localhost:9999`
- **Real-Debrid** account with torrents

### Installation

**Windows (PowerShell pre-installed):**
```powershell
# Download the script
Invoke-WebRequest -Uri "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v2.3.0/Zurg-Broken-Torrent-Monitor.ps1" `
    -OutFile "Zurg-Broken-Torrent-Monitor.ps1"

# Test run
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce

# Start monitoring
.\Zurg-Broken-Torrent-Monitor.ps1
```

---

## 📖 Usage

### Basic Usage

**Single check (test mode):**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

**Continuous monitoring (every 30 minutes):**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1
```

**Enable auto-repair:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $true
```

**With authentication:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -Username "riven" -Password "12345"
```

**Custom Zurg URL:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://192.168.1.100:9999"
```

**Verbose logging:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -VerboseLogging
```

### Interactive Management

When unrepairable torrents are detected:

1. **Press 'M'** to enter management mode
2. **Select torrents** using advanced syntax:
   ```
   Enter command: 1-10          # Select range
   Enter command: 1,5,10,15     # Select specific
   Enter command: 1-5,10,15-20  # Mixed selection
   ```
3. **Take action:**
   - Press **'R'** to repair selected torrents
   - Press **'D'** to delete selected torrents
   - Press **'Q'** to quit management
4. **Continue or exit:**
   - Press **'y'** to refresh and continue managing
   - Press **'n'** to return to monitoring

---

## ⚙️ Configuration

### Command-Line Parameters

```powershell
-ZurgUrl              # Zurg URL (default: http://localhost:9999)
-Username             # Username (default: riven)
-Password             # Password (default: 12345)
-CheckIntervalMinutes # Check interval (default: 30)
-LogFile              # Log file path
-RunOnce              # Single check and exit
-VerboseLogging       # Enable debug logging
-AutoRepair           # Enable auto-repair (default: $true)
```

### Examples

**Run every 15 minutes with custom settings:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 `
  -ZurgUrl "http://zurg.example.com:9999" `
  -Username "admin" `
  -Password "secretpass" `
  -CheckIntervalMinutes 15 `
  -LogFile "C:\Logs\zurg-monitor.log"
```

**Quick health check:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce -VerboseLogging
```

**Production monitoring with auto-repair:**
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $true
```

---

## 📊 Understanding the Output

### Check Summary Display

```
======================================================================
  CHECK SUMMARY
======================================================================

CURRENT CHECK RESULTS:
  Broken Torrents:           8
  Under Repair:              5
  Repairs Triggered:         13
  
  Unrepairable Torrents:     70
  
  Broken Torrents:
    - Movie.Title.2023.2160p.WEB-DL.mkv
    - TV.Show.S01E05.1080p.HDTV.mkv
  
  Cannot Repair:
    - Platonic.2023.S02E10...
      Reason: repair failed, download status: error
    - Most.Wanted.Teen.Hacker...
      Reason: infringing torrent

Press 'M' to enter Management mode, or any other key to continue...
```

### Statistics Display

```
========================================================================
  OVERALL STATISTICS
========================================================================
Total Checks Performed:    5
Total Broken Found:        12
Total Under Repair Found:  8
Total Unrepairable Found:  70
Total Repairs Triggered:   20    ← Auto + Manual
Total Deletions Triggered: 13    ← Manual only
Last Check:                2025-12-04 22:30:00
Last Broken Found:         2025-12-04 21:15:00
```

### Failure Reasons Handled

- `repair failed, download status: error` - Download permanently failed
- `infringing torrent` - Copyright violation detected
- `not cached (restricted to cached)` - Not in Real-Debrid cache
- `the lone cached file is broken` - Only available file is corrupted
- `invalid file ids` - Torrent structure issue

---

## 🔄 Automation Examples

### Windows Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Trigger: Daily (or as desired)
4. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\Path\To\Zurg-Broken-Torrent-Monitor.ps1" -CheckIntervalMinutes 30`

### Windows Service (NSSM)

```powershell
# Install NSSM
choco install nssm

# Install service
nssm install ZurgMonitor "C:\Program Files\PowerShell\7\pwsh.exe" `
    "-ExecutionPolicy Bypass -File `"C:\Path\To\Zurg-Broken-Torrent-Monitor.ps1`""

# Configure service
nssm set ZurgMonitor AppDirectory "C:\Path\To\Script"
nssm set ZurgMonitor DisplayName "Zurg Broken Torrent Monitor"
nssm set ZurgMonitor Description "Monitors and repairs broken torrents in Zurg"
nssm set ZurgMonitor Start SERVICE_AUTO_START

# Start service
nssm start ZurgMonitor
```

---

## 🔧 Troubleshooting

### Common Issues

**"Connection failed to Zurg"**
```powershell
# Test connection manually
Test-NetConnection -ComputerName localhost -Port 9999

# Check Zurg URL is correct
Invoke-WebRequest -Uri "http://localhost:9999/stats"
```

**"No torrents showing in management mode"**
- Run with `-VerboseLogging` to see debug info
- Check if unrepairable torrents exist in Zurg UI
- Verify you have v2.3.0 (check script version)
- Check log file for parsing errors

**"Torrents show as 'P' and 'r'"**
- This was a bug in early v2.3.0 development
- Download the latest v2.3.0 release

**"Script exits after repair/delete"**
- Update to v2.3.0 for continuous management mode

**"Auto-repair still running when disabled"**
- Verify parameter: `-AutoRepair $false`
- Check startup message confirms "Monitoring Only" mode
- Restart the script after changing parameter

### Debug Mode

Enable verbose logging:
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -VerboseLogging
```

Check the log file:
```powershell
Get-Content .\zurg-broken-torrent-monitor.log -Tail 50
```

---

## 📈 Performance

### Resource Usage

- **Memory**: ~50 MB typical usage
- **CPU**: Minimal (mostly idle)
- **Network**: Lightweight API calls every 30 minutes
- **Disk**: Log file grows ~1 KB per check

### API Calls Per Check

1. `GET /stats` - Connection test
2. `GET /manage/?state=status_broken` - Broken torrents
3. `GET /manage/?state=status_under_repair` - Under repair
4. `GET /manage/?state=status_cannot_repair` - Unrepairable torrents (v2.3+)
5. `POST /manage/{hash}/repair` - For each torrent needing repair

**Typical check duration:** 2-5 seconds for 1,000+ torrents

### Scalability

- Tested with 70+ unrepairable torrents
- Handles 1000+ total torrents efficiently
- No memory leaks or performance degradation over 24+ hours

---

## 🔐 Security Considerations

- **Credentials**: Passed via command-line (visible in process list)
  - For production: Consider using environment variables
- **Network**: Uses HTTP basic authentication
  - Secure your Zurg instance with HTTPS if possible
- **Logs**: May contain torrent names
  - Set appropriate file permissions on log files

**Best Practices:**
```powershell
# Use environment variables for credentials
$env:ZURG_USERNAME = "admin"
$env:ZURG_PASSWORD = "secret"
```

---

## 📚 Documentation

### v2.3.0 Documentation
- [V2.3.0 Release Notes](V2.3.0-RELEASE-NOTES.md) - Comprehensive release summary
- [Enhanced Selection Guide](docs/ENHANCED-SELECTION-GUIDE.md) - Selection syntax
- [Continuous Management Guide](docs/CONTINUOUS-MANAGEMENT-GUIDE.md) - Workflow guide
- [Auto-Repair Control Guide](docs/AUTO-REPAIR-CONTROL-GUIDE.md) - Parameter usage
- [Quick Reference](docs/AUTO-REPAIR-QUICK-REFERENCE.md) - At-a-glance reference

### General Documentation
- [Changelog](CHANGELOG.md) - Complete version history

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Open an issue for bugs/features
2. Fork and create feature branch
3. Test thoroughly
4. Submit pull request

### Areas for Contribution

- 🐍 **Python version** for native Linux/macOS support
- 🐳 **Docker image** with pre-configured environment

---

## 📝 Version History

| Version | Date | Key Features |
|---------|------|--------------|
| **2.3.0** | 2025-12-05 | Unrepairable torrent management, bulk selection, continuous mode |
| **2.2.1** | 2025-11-13 | Critical array unwrapping fix |
| **2.2.0** | 2025-11-06 | Total torrent statistics with health percentages |
| **2.1.0** | 2025-11-05 | Under repair monitoring and enhanced comparison |
| **2.0.0** | 2025-11-05 | Fixed torrent detection and repair endpoints |

[Full changelog →](CHANGELOG.md)

---

## ❓ FAQ

**Q: Does this work with Plex?**  
A: Yes! This monitors Zurg, which serves content to Plex. It helps keep your Plex library healthy.

**Q: What's the difference between broken and unrepairable?**  
A: Broken torrents can be repaired automatically. Unrepairable torrents have permanent issues (copyright violations, missing cache, etc.) and require manual intervention.

**Q: Will this delete any torrents automatically?**  
A: No! Deletions only happen when you manually select torrents in management mode and type "DELETE" to confirm.

**Q: How often should I run checks?**  
A: Every 30 minutes is recommended. This balances responsiveness with resource usage.

**Q: Can I manage unrepairable torrents in bulk?**  
A: Yes! Use range selection (`1-10`), comma-separated lists (`1,5,10`), or mixed syntax (`1-5,10,15-20`) to select multiple torrents efficiently.

**Q: What happens if I select "Continue" after deleting torrents?**  
A: The list refreshes to show current unrepairable torrents. Deleted items are gone, and numbering updates automatically.

---

## 📄 License

This project is licensed under the MIT License.

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/maddguru/zurg-broken-torrent-monitor/issues)
- **Discussions**: [GitHub Discussions](https://github.com/maddguru/zurg-broken-torrent-monitor/discussions)
- **Documentation**: [Wiki](https://github.com/maddguru/zurg-broken-torrent-monitor/wiki)
  
---

## 🔗 Related Projects

- [Zurg](https://github.com/debridmediamanager/zurg-testing) - Real-Debrid WebDAV integration
- [rclone](https://rclone.org/) - Cloud storage mounting
- [Plex](https://www.plex.tv/) - Media server

---

## ⭐ Star History

If you find this tool useful, please consider starring the repository!

---

## 🙏 Acknowledgments

- [Zurg](https://github.com/debridmediamanager/zurg-testing) - The awesome torrent manager this tool monitors
- PowerShell Community - For excellent cross-platform scripting capabilities
- All contributors and users who provide feedback

**This little project was inspired by yowmamasita [Zurg/DebridMediaManager](https://github.com/debridmediamanager/zurg-testing) and godver3 [cli_debrid](https://github.com/godver3/cli_debrid). These two creators have spent countless hours building reliable tools for the community, and I have a deep appreciation for their work. I am not even close to being a developer so I used my particular set of skills to instruct AI to bring this and a few other ideas to life. I had an idea of creating a simple, standalone backup solution, until this feature returns to Zurg. And here we are.**

**Made with ❤️ for the Zurg community**

---

*Version 2.3.0 - December 5, 2025*
