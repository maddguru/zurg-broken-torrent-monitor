# Zurg Broken Torrent Monitor & Repair Tool

[![Version](https://img.shields.io/badge/version-2.5.2-blue.svg)](https://github.com/maddguru/zurg-broken-torrent-monitor/releases/latest)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/PowerShell/PowerShell#get-powershell)

**Automated monitoring and management of broken, under-repair, and unrepairable torrents in Zurg + Real-Debrid setups.**

---

## 🎯 Overview

Zurg Broken Torrent Monitor is a PowerShell script that continuously monitors your Zurg instance for broken, under-repair, and unrepairable torrents. It provides a unified management interface, automatic repairs, and comprehensive statistics about your torrent library's health.

## Features

### Core Monitoring
- 🔍 **Automatic Detection** - Continuously monitors Zurg for broken torrents
- 🔧 **Auto-Repair** - Optionally trigger repairs automatically (toggle with `T`)
- 📊 **Statistics Tracking** - Detailed stats on checks, repairs, and verifications
- ⌨️ **Hotkey Controls** - Quick access to all features without stopping monitoring

### Health Verification (New in v2.5.2)
- 🏥 **Library Health Scan** - Verify all "OK" torrents have correct actual status
- 🎯 **Mismatch Detection** - Find torrents where reported ≠ actual status
- 📈 **Live Progress** - Real-time progress bar with ETA and memory usage
- 🚀 **Startup Verification** - Optional scan on script start (toggle with `TV`)

### Settings & Memory
- 💾 **Persistent Settings** - AutoRepair/AutoVerify preferences saved to JSON
- 🧠 **Memory Optimized** - Efficient handling for large libraries (5000+ torrents)
- 📉 **Memory Display** - Current usage shown in status bar

### Management Interface
- 📋 **Torrent Management** - View, filter, and manage problem torrents
- 🏷️ **Smart Filtering** - Filter by Broken, Under Repair, or Mismatch status
- 🎯 **Bulk Operations** - Repair or delete multiple torrents at once
- 🔢 **Pagination** - Handle large torrent lists efficiently

---

## 📊 What's New in v2.5.2

**Health Verification System:**

Press `V` anytime during monitoring to scan your entire library for torrents with mismatched status. The verification feature provides:

- 🔍 **Comprehensive Scanning** - Checks all "OK" torrents for actual state mismatches
- 📊 **Live Progress** - Real-time progress bar with ETA and memory usage
- ⚡ **Fast & Efficient** - Optimized for libraries with 5000+ torrents
- 💾 **Persistent Settings** - AutoRepair and AutoVerify preferences saved automatically

**Wait Screen with Health Verify:**

```
======================================================================
  WAITING FOR NEXT CHECK                              Mem: 45.23 MB
  Press: [M] Management  [S] Stats  [V] Health Verify  [Ctrl+C] Exit
======================================================================

  [████████░░░░░░░░░░░░] Next check in: 22m 15s (at 18:45:30)
```

**Verification Progress:**

```
  [████████████░░░░░░░░░░░░░░░░░░] 40.2% | 2335/5812 | ETA: 6m 12s | Mismatches: 3 | Mem: 52.18MB
```

---

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7.0+** (tested on 7.5.4)
- **Zurg** running and accessible
- **Real-Debrid** account with torrents

### Installation

```powershell
# Download the script
Invoke-WebRequest -Uri "https://github.com/maddguru/zurg-broken-torrent-monitor/releases/download/v2.5.2/Zurg-Broken-Torrent-Monitor.ps1" -OutFile "Zurg-Broken-Torrent-Monitor.ps1"

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
| **2.5.2** | 2025-12-11 | Health verification system and persistent settings |
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
