# 🎯 Auto-Repair Parameter - Quick Reference

## Parameter

```powershell
-AutoRepair <Boolean>
```

**Default:** `$true` (enabled)  
**Type:** Boolean  
**Values:** `$true` or `$false`

---

## Quick Examples

### Enable Auto-Repair (Default)
```powershell
# These are all the same:
.\Zurg-Broken-Torrent-Monitor.ps1
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $true
```

### Disable Auto-Repair (Monitoring Only)
```powershell
.\Zurg-Broken-Torrent-Monitor.ps1 -AutoRepair $false
```

---

## Common Use Cases

| Scenario | Command |
|----------|---------|
| **Production (auto-fix everything)** | `.\script.ps1` |
| **Testing (see but don't fix)** | `.\script.ps1 -AutoRepair $false` |
| **Quick check (no changes)** | `.\script.ps1 -AutoRepair $false -RunOnce` |
| **Continuous monitoring only** | `.\script.ps1 -AutoRepair $false -CheckIntervalMinutes 30` |

---

## What Changes

| Feature | AutoRepair=$true | AutoRepair=$false |
|---------|------------------|-------------------|
| Detect broken | ✅ | ✅ |
| Detect under-repair | ✅ | ✅ |
| Detect unrepairable | ✅ | ✅ |
| **Auto-trigger repairs** | ✅ | ❌ |
| Show statistics | ✅ | ✅ |
| Manual management (M) | ✅ | ✅ |

---

## Output Indicators

### With AutoRepair=$true (Default)
```
[INFO] Auto-Repair: Enabled
[INFO] Triggering repairs...
[SUCCESS] Repair triggered for: Movie.Title...
  Repairs Triggered:         7
```

### With AutoRepair=$false
```
[INFO] Auto-Repair: Disabled (Monitoring Only)
[INFO] Auto-repair disabled - monitoring only mode
  Repairs Triggered:         0
```

---

## Combined Parameters

```powershell
# Full example
.\Zurg-Broken-Torrent-Monitor.ps1 `
  -ZurgUrl "http://localhost:9999" `
  -Username "riven" `
  -Password "12345" `
  -AutoRepair $false `              ← Monitoring only
  -CheckIntervalMinutes 30 `
  -VerboseLogging
```

---

## Quick Decision Tree

```
Do you want the script to automatically fix broken torrents?

YES → Use default (omit parameter or -AutoRepair $true)
  ↓
  Repairs trigger automatically

NO → Use -AutoRepair $false
  ↓
  Monitoring only, you decide when to repair
```

---

## When to Use Each

### AutoRepair=$true (Default)
- ✅ Production environments
- ✅ You trust the repair process
- ✅ Want hands-off operation
- ✅ Running as a service

### AutoRepair=$false
- ✅ Testing the script
- ✅ High failure rate (want to review first)
- ✅ Selective repair approach
- ✅ Collecting statistics only
- ✅ Manual control preferred

---

## In Code

The parameter is defined as:
```powershell
[bool]$AutoRepair = $true
```

Used in checks like:
```powershell
if ($AutoRepair) {
    # Trigger repairs
} else {
    # Skip repairs (monitoring only)
}
```

---

## FAQ

**Q: What's the default if I don't specify?**  
A: Auto-repair is **enabled** by default (`$true`)

**Q: Can I change it while running?**  
A: No, you need to restart with the desired value

**Q: Does monitoring mode still detect everything?**  
A: Yes! It detects all issues, just doesn't auto-repair them

**Q: Can I still manually repair in monitoring mode?**  
A: Yes! Use the unrepairable management interface (Press 'M')

---

## Version

**Added in:** v2.3.0  
**Parameter:** `-AutoRepair`  
**Type:** Boolean  
**Default:** `$true`

---

**Quick tip:** Start with `-AutoRepair $false` to test, then enable it for production! 🎯
