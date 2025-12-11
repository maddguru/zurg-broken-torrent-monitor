# Zurg Broken Torrent Monitor & Repair Tool

[![Version](https://img.shields.io/badge/version-2.4.0-blue.svg)](https://github.com/maddguru/zurg-broken-torrent-monitor/releases/latest)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/PowerShell/PowerShell#get-powershell)

**Automated monitoring and management of broken, under-repair, and unrepairable torrents in Zurg + Real-Debrid setups.**

---

## 🎯 Overview

Zurg Broken Torrent Monitor is a PowerShell script that continuously monitors your Zurg instance for broken, under-repair, and unrepairable torrents. It provides a unified management interface, automatic repairs, and comprehensive statistics about your torrent library's health.

### Key Features

**Core Monitoring:**
- 🔍 **Broken Torrent Detection** - Automatically detects torrents in broken state
- 🔧 **Automatic Repairs** - Optional auto-repair for broken torrents
- 🔄 **Under-Repair Monitoring** - Tracks torrents currently being repaired
- 📊 **Statistics Tracking** - Comprehensive stats for all operations

**v2.4.0 - Unified Management Center:**
- 🆕 **Unified Management UI** - ALL torrent types in one interface (Broken, Under Repair, Unrepairable)
- 🆕 **Advanced Filtering** - Filter by state, search by name, filter by reason
- 🆕 **Bulk Select by Reason** - Select all torrents matching a reason pattern
- 🆕 **Live AutoRepair Toggle** - Toggle AutoRepair ON/OFF without restarting
- 🆕 **Hotkeys During Wait** - Press 'M' anytime to enter Management, 'S' for Stats

**Previous Features (v2.3.0):**
- ✅ **Bulk Selection** - Advanced selection: single, ranges (`1-10`), lists (`1,5,10`), mixed (`1-5,10,15-20`)
- ✅ **Continuous Management** - Stay in management mode, refresh after actions
- ✅ **Repair or Delete** - Choose to repair or delete selected torrents
- ✅ **Deletion Tracking** - Statistics for manual deletions

---

## 📊 What's New in v2.4.0

**Unified Torrent Management Center** - The flagship feature of this release:

```
======================================================================
  TORRENT MANAGEMENT CENTER v2.4.0
======================================================================

Total: 25 torrents  |  Broken: 3  |  Under Repair: 7  |  Unrepairable: 15

AutoRepair: OFF

----------------------------------------------------------------------

  1. [ ] [BRK] Movie.Title.2023.2160p.WEB-DL.DDP5.1.mkv
  2. [ ] [REP] TV.Show.S01E05.1080p.HDTV.x264.mkv
  3. [ ] [BAD] Platonic.2023.S02E10.Brett.Coyotes.Last.Stand...
          Reason: repair failed, download status: error
```

**Hotkeys During Monitoring:**
```
[INFO] Next check in 30 minutes... (Press 'M' for Management, 'S' for Stats)
```

Press `M` anytime to jump into management, `S` to view statistics!

---

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7.0+** (tested on 7.5.4)
- **Zurg** running and accessible
- **Real-Debrid** account with torrents

### Installation

```powershell
# Download the script
Invoke-WebRequest -Uri "https://github.com/maddguru/zurg-broken-torrent-monitor/releases/download/v2.4.0/Zurg-Broken-Torrent-Monitor.ps1" -OutFile "Zurg-Broken-Torrent-Monitor.ps1"

# Test run
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce

# Start monitoring
.\Zurg-Broken-Torrent-Monitor.ps1
```

---

## 📖 Usage

### Basic Usage

```powershell
# Single check (test mode)
.\Zurg-Broken-Torrent-Monitor.ps1 -RunOnce

# Continuous monitoring (every 30 minutes)
.\Zurg-Broken-Torrent-Monitor.ps1

# Enable auto-repair
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $true

# With authentication
.\Zurg-Broken-Torrent-Monitor.ps1 -Username "riven" -Password "12345"

# Custom Zurg URL
.\Zurg-Broken-Torrent-Monitor.ps1 -ZurgUrl "http://192.168.1.100:9999"
```

### Management Commands

| Command | Action |
|---------|--------|
| `#`, `#-#`, `#,#` | Toggle selection (single, range, list) |
| `A` / `N` | Select All / None |
| `FB` / `FU` / `FC` | Filter Broken / Under Repair / Cannot Repair |
| `F*` | Show All |
| `FS` / `FR` | Search by name / Filter by reason |
| `FX` | Clear all filters |
| `BR` | Bulk select by reason |
| `R` / `D` | Repair / Delete selected |
| `T` | Toggle AutoRepair |
| `L` | Refresh list |
| `Q` | Quit to monitoring |

---

## ⚙️ Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ZurgUrl` | `http://localhost:9999` | Zurg URL |
| `-Username` | `riven` | Username |
| `-Password` | `12345` | Password |
| `-CheckIntervalMinutes` | `30` | Check interval |
| `-LogFile` | `zurg-broken-torrent-monitor.log` | Log file |
| `-RunOnce` | `$false` | Single check mode |
| `-VerboseLogging` | `$false` | Debug logging |
| `-AutoRepair` | `$false` | Auto-repair mode |

---

## 📝 Version History

| Version | Date | Features |
|---------|------|----------|
| **2.4.0** | 2025-12-10 | Unified Management, filtering, bulk by reason, live AutoRepair toggle, hotkeys |
| **2.3.0** | 2025-12-05 | Unrepairable management, bulk selection, continuous mode |
| **2.2.1** | 2025-11-13 | Array unwrapping fix |
| **2.2.0** | 2025-11-06 | Total torrent statistics |

---

## 🙏 Acknowledgments

This little project was inspired by yowmamasita [Zurg/DebridMediaManager](https://github.com/debridmediamanager/zurg-testing) and godver3 [cli_debrid](https://github.com/godver3/cli_debrid). These two creators have spent countless hours building reliable tools for the community, and I have a deep appreciation for their work. I am not even close to being a developer so I used my particular set of skills to instruct AI to bring this and a few other ideas to life. I had an idea of creating a simple, standalone backup solution, until this feature returns to Zurg. And here we are.

---

**Made with ❤️ for the Zurg community**

*Version 2.4.0 - December 10, 2025*
