# Zurg Broken Torrent Monitor & Repair Tool

[![Version](https://img.shields.io/badge/version-2.2.0-blue.svg)](https://github.com/maddguru/zurg-broken-torrent-monitor/releases/latest)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/PowerShell/PowerShell#get-powershell)

**Automatically monitor and repair broken torrents in Zurg with comprehensive library health statistics.**

---

## 🎯 Overview

Zurg Broken Torrent Monitor is a PowerShell script that continuously monitors your Zurg instance for broken and under-repair torrents, automatically triggers repairs, and provides detailed statistics about your entire torrent library's health.

### Key Features

- 🔍 **Monitors Broken Torrents** - Detects torrents in broken state
- 🔧 **Automatic Repairs** - Triggers repair API for broken torrents
- 🔄 **Under Repair Tracking** - Monitors and re-triggers stuck repairs
- 📊 **Total Library Statistics** (NEW in v2.2) - Complete torrent count with health percentages
- 📈 **Progress Tracking** - Compares results between checks
- ✅ **Success Rate Metrics** - Shows repair effectiveness
- 🎨 **Color-Coded Output** - Easy-to-read visual feedback
- 📝 **Comprehensive Logging** - Detailed logs for troubleshooting
- ⚙️ **Flexible Scheduling** - Run once or continuous monitoring
- 🔐 **Authentication Support** - Basic auth for secured Zurg instances

---

## 📊 What's New in v2.2

**Total Torrent Statistics Display:**

```
TORRENT STATISTICS:
  Total Torrents:            5,277
  OK Torrents:               5,264 (99.75%)
  Broken:                        8 (0.15%)
  Under Repair:                  5 (0.10%)
```

Get instant visibility into your entire library's health with contextual percentages that help you understand whether issues are isolated or widespread.

[See full v2.2 update notes →](V2.2-UPDATE-NOTES.md)

---

## 📸 Screenshots

### Check Summary
```
======================================================================
  CHECK SUMMARY
======================================================================

TORRENT STATISTICS:
  Total Torrents:            5,277
  OK Torrents:               5,264 (99.75%)
  Broken:                        8 (0.15%)
  Under Repair:                  5 (0.10%)

CURRENT CHECK RESULTS:
  Broken Torrents:           8
  Under Repair:              5
  Repairs Triggered:         13

  Broken Torrents:
    - Movie.Title.2023.2160p.WEB-DL.mkv
    - TV.Show.S01E05.1080p.HDTV.mkv
    ...

COMPARISON WITH PREVIOUS CHECK:
  Successfully Repaired:     3
  Moved to Repair:           2
  Still Broken:              3
  Still Under Repair:        2
  New Broken:                1
  Repair Success Rate:       60.0%
```

---

## 🚀 Quick Start

### Prerequisites

- **Zurg** instance running and accessible
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7.0+** (Linux/macOS)
- Network access to Zurg's web interface

### Installation

**Windows (PowerShell pre-installed):**
```powershell
# Download the script
Invoke-WebRequest -Uri "https://github.com/maddguru/zurg-broken-torrent-monitor/releases/download/v2.2.0/Zurg-Broken-Torrent-Monitor.ps1" -OutFile "Zurg-Broken-Torrent-Monitor.ps1"

# Run it
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

**Linux:**
```bash
# Install PowerShell Core (if not already installed)
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install -y powershell

# Download the script
wget https://github.com/maddguru/zurg-broken-torrent-monitor/releases/download/v2.2.0/Zurg-Broken-Torrent-Monitor.ps1

# Run it
pwsh ./Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

**macOS:**
```bash
# Install PowerShell Core (if not already installed)
brew install powershell

# Download the script
curl -L -O https://github.com/maddguru/zurg-broken-torrent-monitor/releases/download/v2.2.0/Zurg-Broken-Torrent-Monitor.ps1

# Run it
pwsh ./Zurg-Broken-Torrent-Monitor.ps1 -RunOnce
```

**Docker (Alternative):**
```bash
# Run directly in a PowerShell container
docker run --rm -v $(pwd):/workspace mcr.microsoft.com/powershell:latest \
  pwsh /workspace/Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://host.docker.internal:9999" -RunOnce
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
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 30
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

---

## ⚙️ Configuration

### Command-Line Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ZurgUrl` | String | `http://localhost:9999` | Base URL of your Zurg instance |
| `-Username` | String | `riven` | Username for Zurg authentication |
| `-Password` | String | `12345` | Password for Zurg authentication |
| `-CheckIntervalMinutes` | Integer | `30` | Minutes between checks (min: 1) |
| `-LogFile` | String | `zurg-broken-torrent-monitor.log` | Path to log file |
| `-RunOnce` | Switch | `false` | Run a single check and exit |
| `-VerboseLogging` | Switch | `false` | Enable detailed debug output |

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

---

## 🖥️ Platform Support

### Windows
- ✅ **Built-in Support** - PowerShell 5.1+ comes pre-installed
- ✅ **Windows Service** - Can run as a service with NSSM
- ✅ **Task Scheduler** - Easy scheduling with Windows Task Scheduler

### Linux
- ✅ **PowerShell Core** - Install via package manager
- ✅ **Systemd** - Run as a systemd service
- ✅ **Cron** - Schedule with cron jobs
- ✅ **Docker** - Run in containers

### macOS
- ✅ **PowerShell Core** - Install via Homebrew
- ✅ **LaunchAgent** - Run as a launch agent
- ✅ **Cron** - Schedule with cron jobs

**Installing PowerShell Core:**

| Platform | Installation Command |
|----------|---------------------|
| **Ubuntu/Debian** | `sudo apt-get install -y powershell` |
| **CentOS/RHEL** | `sudo yum install -y powershell` |
| **Fedora** | `sudo dnf install -y powershell` |
| **macOS** | `brew install powershell` |
| **Windows** | Pre-installed (5.1+) or [Download PowerShell 7+](https://aka.ms/powershell) |
| **Docker** | `docker pull mcr.microsoft.com/powershell:latest` |

[PowerShell Installation Guide →](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)

---

## 🔄 Automation Examples

### Windows Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Trigger: Daily (or as desired)
4. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\Path\To\Zurg-Broken-Torrent-Monitor.ps1" -CheckIntervalMinutes 30`

### Linux Systemd Service

Create `/etc/systemd/system/zurg-monitor.service`:

```ini
[Unit]
Description=Zurg Broken Torrent Monitor
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/opt/zurg-monitor
ExecStart=/usr/bin/pwsh /opt/zurg-monitor/Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 30
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable zurg-monitor
sudo systemctl start zurg-monitor
sudo systemctl status zurg-monitor
```

### Linux Cron Job

Run every 30 minutes:
```bash
crontab -e

# Add this line:
*/30 * * * * /usr/bin/pwsh /path/to/Zurg-Broken-Torrent-Monitor.ps1 -RunOnce >> /var/log/zurg-monitor.log 2>&1
```

### Docker Compose

```yaml
version: '3.8'

services:
  zurg-monitor:
    image: mcr.microsoft.com/powershell:latest
    container_name: zurg-monitor
    volumes:
      - ./Zurg-Broken-Torrent-Monitor.ps1:/app/monitor.ps1
      - ./logs:/logs
    command: >
      pwsh /app/monitor.ps1
      -ZurgUrl "http://zurg:9999"
      -CheckIntervalMinutes 30
      -LogFile "/logs/zurg-monitor.log"
    restart: unless-stopped
```

---

## 📊 Understanding the Output

### Torrent Statistics Section (v2.2+)

- **Total Torrents**: Complete count of all torrents in Zurg
- **OK Torrents**: Working torrents (percentage of total)
- **Broken**: Torrents that failed and need repair
- **Under Repair**: Torrents currently being repaired

**Health Guidelines:**

| Broken % | Status | Recommended Action |
|----------|--------|-------------------|
| 0-0.5% | 😊 Excellent | Continue monitoring |
| 0.5-2% | 😐 Acceptable | Keep an eye on trends |
| 2-5% | 😟 Concerning | Investigate causes |
| 5%+ | 😱 Critical | Immediate attention needed |

### Comparison Section

Shows progress since last check:
- **Successfully Repaired**: Torrents that were fixed
- **Moved to Repair**: Torrents that transitioned from broken to repairing
- **Still Broken**: Torrents that remain broken
- **Still Under Repair**: Torrents still being repaired
- **New Broken**: Newly detected broken torrents
- **Repair Success Rate**: Percentage of repairs that completed

---

## 🔧 Troubleshooting

### Common Issues

**"Cannot connect to Zurg"**
```powershell
# Test connection manually
Test-NetConnection -ComputerName localhost -Port 9999

# Check Zurg URL is correct
curl http://localhost:9999/stats
```

**"Total Torrents shows 0"**
- Verify `/manage/` endpoint is accessible
- Check authentication credentials
- Enable verbose logging: `-VerboseLogging`

**"Script shows wrong version"**
```powershell
# Check script version
Get-Content .\Zurg-Broken-Torrent-Monitor.ps1 | Select-String "v2.2"
```

**"Repairs not working"**
- Verify Zurg's repair functionality is working via web UI
- Check logs for API errors
- Ensure proper authentication

**Cross-platform path issues (Linux/macOS):**
```bash
# Use forward slashes for log file paths
pwsh ./Zurg-Broken-Torrent-Monitor.ps1 -LogFile "/var/log/zurg-monitor.log"
```

### Debug Mode

Enable verbose logging to see detailed information:
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -VerboseLogging
```

Check the log file:
```powershell
# Windows
Get-Content .\zurg-broken-torrent-monitor.log -Tail 50

# Linux/macOS
tail -f zurg-broken-torrent-monitor.log
```

---

## 📈 Performance

### Resource Usage

- **Memory**: ~20-40 MB during execution
- **CPU**: Minimal (< 1% average)
- **Network**: 3 HTTP requests per check cycle
- **Disk**: Log file grows ~1 KB per check

### API Calls Per Check

1. `GET /stats` - Connection test
2. `GET /manage/?state=status_broken` - Broken torrents
3. `GET /manage/?state=status_under_repair` - Under repair
4. `GET /manage/` - Total torrent count (v2.2+)
5. `POST /manage/{hash}/repair` - For each torrent needing repair

**Typical check duration:** 2-5 seconds for 5,000+ torrents

---

## 🔐 Security Considerations

- **Credentials**: Passed via command-line (visible in process list)
  - For production: Consider using Windows Credential Manager or environment variables
- **Network**: Uses HTTP basic authentication
  - Secure your Zurg instance with HTTPS if possible
- **Logs**: May contain torrent names
  - Set appropriate file permissions on log files

**Best Practices:**
```powershell
# Use environment variables for credentials
$env:ZURG_USERNAME = "admin"
$env:ZURG_PASSWORD = "secret"

# Reference in script execution or modify script to read from env
```

---

## 📚 Documentation

- [V2.2 Update Notes](V2.2-UPDATE-NOTES.md) - What's new in v2.2
- [Quick Reference](V2.2-QUICK-REFERENCE.md) - Quick feature overview
- [Changelog](CHANGELOG.md) - Complete version history
- [Contributing](CONTRIBUTING.md) - How to contribute
- [Configuration Guide](CONFIGURATION.md) - Advanced configuration

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas for Contribution

- 🐍 **Python version** for better Linux/macOS native support
- 🐳 **Docker image** with pre-configured environment
  
---

## 📝 Version History

| Version | Date | Key Features |
|---------|------|--------------|
| **2.2.0** | 2025-11-06 | Total torrent statistics with health percentages |
| **2.1.0** | 2025-11-05 | Under repair monitoring and enhanced comparison |
| **2.0.0** | 2025-11-05 | Fixed torrent detection and repair endpoints |
| **1.0.0** | 2025-10-28 | Initial release with basic monitoring |

[Full changelog →](CHANGELOG.md)

---

## ❓ FAQ

**Q: Does this work with Plex?**  
A: Yes! This monitors Zurg, which serves content to Plex. It helps keep your Plex library healthy.

**Q: Can I run this on a NAS?**  
A: Yes, if your NAS supports PowerShell Core or Docker.

**Q: How often should I run checks?**  
A: Every 15-30 minutes is recommended. More frequent checks won't harm but may be unnecessary.

**Q: Will this delete any torrents?**  
A: No, it only triggers Zurg's repair function. It never deletes anything.

**Q: Why PowerShell instead of Python/Bash?**  
A: PowerShell provides excellent HTTP/JSON handling and cross-platform support. However, a Python version may be added in the future for users who prefer it.

---

## 📄 License

This project will be free for the community to use.

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

**This little project was inspired by yowmamasita [Zurg/DebridMediaManager](https://github.com/debridmediamanager/zurg-testing) and godver3 [cli_debrid](https://github.com/godver3/cli_debrid). These two creators have spent countless hours building reliable tools for the community, and I have a deep appreciation for their work.  I am not even close to being a developer so I used my particular set of skills to instruct AI to bring this and a few other ideas to life. I had an idea of creating a simple, standalone backup solution, until this feature returns to Zurg. And here we are.**

**Made with ❤️ for the Zurg community**

[⬆ Back to top](#zurg-broken-torrent-monitor--repair-tool)
