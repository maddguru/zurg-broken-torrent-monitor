# 🔧 Auto-Repair Control Feature

## Overview

The `-AutoRepair` parameter controls whether the script automatically triggers repairs for broken torrents.

**Default:** `$true` (auto-repair enabled)

---

## Usage

### Monitoring Only Mode (No Auto-Repair)

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false
```

**What happens:**
- ✅ Detects broken torrents
- ✅ Detects under-repair torrents
- ✅ Detects unrepairable torrents
- ✅ Shows statistics and summaries
- ✅ Allows manual management of unrepairable (Press 'M')
- ❌ Does NOT automatically trigger repairs

### Normal Mode (Auto-Repair Enabled) - DEFAULT

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1
# Or explicitly:
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $true
```

**What happens:**
- ✅ Detects broken torrents
- ✅ **Automatically triggers repairs**
- ✅ Re-triggers repairs for under-repair torrents
- ✅ Detects unrepairable torrents
- ✅ Shows statistics and summaries
- ✅ Allows manual management of unrepairable (Press 'M')

---

## When to Use Each Mode

### Use Monitoring Only (`-AutoRepair $false`) When:

1. **Initial Testing** - You want to see what would be repaired without actually doing it
2. **Scheduled Maintenance** - You want to review issues before taking action
3. **High Failure Rate** - Many torrents are breaking and you want to investigate before mass-repairing
4. **Cautious Approach** - You prefer to manually review and repair selectively
5. **Analysis** - You want to collect statistics without making changes

### Use Normal Mode (Default) When:

1. **Automated Operation** - You want hands-off automatic repair
2. **Stable System** - Occasional breaks that should be fixed immediately
3. **24/7 Monitoring** - Running as a service that should fix issues as they occur
4. **Production Environment** - Your library needs to stay healthy automatically

---

## Output Differences

### Monitoring Only Mode

```
========================================================================
  ZURG BROKEN TORRENT MONITOR v2.3.0
========================================================================
[2025-12-04 16:30:00] [INFO] Starting Zurg Broken Torrent Monitor
[2025-12-04 16:30:00] [INFO] Zurg URL: http://localhost:9999
[2025-12-04 16:30:00] [INFO] Check Interval: 30 minutes
[2025-12-04 16:30:00] [INFO] Log File: zurg-broken-torrent-monitor.log
[2025-12-04 16:30:00] [INFO] Authentication: Enabled
[2025-12-04 16:30:00] [INFO] Auto-Repair: Disabled (Monitoring Only)  ← NEW!

[2025-12-04 16:30:02] [INFO] Found 5 broken torrent(s)
[2025-12-04 16:30:02] [INFO] Found 2 under repair torrent(s)
[2025-12-04 16:30:02] [INFO]
[2025-12-04 16:30:02] [INFO] Auto-repair disabled - monitoring only mode  ← NEW!

======================================================================
  CHECK SUMMARY
======================================================================

TORRENT STATISTICS:
  Total Torrents:            5,457
  OK Torrents:               5,450 (99.87%)
  Broken:                    5 (0.09%)
  Under Repair:              2 (0.04%)

CURRENT CHECK RESULTS:
  Broken Torrents:           5
  Under Repair:              2
  Repairs Triggered:         0  ← Nothing triggered!
```

### Normal Mode (Auto-Repair)

```
========================================================================
  ZURG BROKEN TORRENT MONITOR v2.3.0
========================================================================
[2025-12-04 16:30:00] [INFO] Starting Zurg Broken Torrent Monitor
[2025-12-04 16:30:00] [INFO] Zurg URL: http://localhost:9999
[2025-12-04 16:30:00] [INFO] Check Interval: 30 minutes
[2025-12-04 16:30:00] [INFO] Log File: zurg-broken-torrent-monitor.log
[2025-12-04 16:30:00] [INFO] Authentication: Enabled
[2025-12-04 16:30:00] [INFO] Auto-Repair: Enabled  ← Shows enabled!

[2025-12-04 16:30:02] [INFO] Found 5 broken torrent(s)
[2025-12-04 16:30:02] [INFO] Found 2 under repair torrent(s)
[2025-12-04 16:30:02] [INFO]
[2025-12-04 16:30:02] [INFO] Triggering repairs...

[2025-12-04 16:30:03] [SUCCESS] Repair triggered for: Movie.Title.2023...
[2025-12-04 16:30:04] [SUCCESS] Repair triggered for: Show.Name.S01E05...
[2025-12-04 16:30:04] [SUCCESS] Repair triggered for: Another.Movie...
[2025-12-04 16:30:05] [SUCCESS] Repair triggered for: Series.S02E10...
[2025-12-04 16:30:06] [SUCCESS] Repair triggered for: Film.Title...

CURRENT CHECK RESULTS:
  Broken Torrents:           5
  Under Repair:              2
  Repairs Triggered:         7  ← Repairs triggered!
```

---

## Combined Usage Examples

### Monitor Only with Verbose Logging

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false -VerboseLogging
```

Great for troubleshooting and seeing detailed information without making changes.

### Monitor Only, Run Once

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false -RunOnce
```

Perfect for scheduled tasks where you just want to check status without auto-repairing.

### Monitor Only, Custom Interval

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false -CheckIntervalMinutes 60
```

Check every hour but don't auto-repair anything.

---

## Workflow: Review Then Repair

You can use monitoring mode to review, then switch to auto-repair:

### Step 1: Monitor First
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false -RunOnce
```

**Output:**
```
Found 5 broken torrent(s)
Found 2 under repair torrent(s)
Found 3 unrepairable torrent(s)

Press 'M' to enter Management mode...
```

### Step 2: Review Unrepairable (Optional)
Press 'M' to manage unrepairable torrents
- Delete the ones you don't want
- Keep the ones that might recover

### Step 3: Enable Auto-Repair
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1
```

Now it will automatically repair the remaining broken torrents.

---

## Impact on Statistics

**Both modes track the same statistics**, but:

| Statistic | Monitoring Only | Auto-Repair Enabled |
|-----------|----------------|---------------------|
| Total Broken Found | ✅ Counted | ✅ Counted |
| Total Under Repair | ✅ Counted | ✅ Counted |
| Total Unrepairable | ✅ Counted | ✅ Counted |
| **Repairs Triggered** | ❌ Always 0 | ✅ Counted |

---

## Continuous Monitoring

### Monitoring Only Service
```powershell
# Run continuously in monitoring-only mode
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false -CheckIntervalMinutes 30
```

**Use case:** You want alerts/stats but prefer to manually decide when to repair.

### Auto-Repair Service (Default)
```powershell
# Run continuously with auto-repair
.\Zurg-Broken-Torrent-Monitor.ps1 -CheckIntervalMinutes 30
```

**Use case:** Production environment that should self-heal.

---

## Parameter Reference

```powershell
-AutoRepair $false
```

**Type:** Switch (flag)  
**Default:** `$false` (auto-repair enabled)  
**Required:** No  
**Position:** Named  

**Examples:**
```powershell
# Enable the switch
-AutoRepair $false

# Or explicitly
-AutoRepair $false:$true

# Disable (enable auto-repair) - same as omitting it
-AutoRepair $false:$false
```

---

## Combining with Other Parameters

### All parameters work together:

```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 `
  -ZurgUrl "http://localhost:9999" `
  -Username "riven" `
  -Password "12345" `
  -CheckIntervalMinutes 30 `
  -AutoRepair $false `           ← Monitoring only
  -VerboseLogging                ← With verbose output
```

---

## FAQ

### Q: Can I toggle auto-repair while the script is running?
**A:** No, you need to restart the script with or without `-AutoRepair $false`.

### Q: Does monitoring-only mode still show unrepairable management?
**A:** Yes! You can still press 'M' to manage unrepairable torrents (repair or delete).

### Q: Will statistics be different between modes?
**A:** "Repairs Triggered" will always be 0 in monitoring-only mode. Everything else is the same.

### Q: Can I use this for testing before going to production?
**A:** Yes! That's one of the primary use cases. Test with `-AutoRepair $false` first.

### Q: Does it still check for broken torrents in monitoring-only mode?
**A:** Yes, it detects everything normally - it just doesn't trigger automatic repairs.

---

## Version Info

**Added in:** v2.3.0  
**Parameter:** `-AutoRepair $false`  
**Type:** Switch  
**Default:** Auto-repair enabled  

---

## Quick Reference

| Want To... | Command |
|-----------|---------|
| Auto-repair (default) | `.\script.ps1` |
| Monitor only | `.\script.ps1 -AutoRepair $false` |
| Test before enabling repairs | `.\script.ps1 -AutoRepair $false -RunOnce` |
| Continuous monitoring only | `.\script.ps1 -AutoRepair $false -CheckIntervalMinutes 30` |

---

**Monitoring only mode gives you full visibility with zero automatic actions!** 🔍
