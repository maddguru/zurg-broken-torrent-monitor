# Continuous Management Mode

## Overview
The unrepairable torrent management interface now **loops continuously**, allowing you to repair or delete multiple batches without exiting back to monitoring mode.

---

## New Workflow

### Before (v2.3.0 - Original)
```
1. Press 'M' to enter management
2. Select torrents
3. Repair or Delete
4. ❌ EXITS to monitoring (no way to continue)
5. Wait 30 minutes for next check
6. Press 'M' again to continue cleanup
```

### After (v2.3.0 - Enhanced)
```
1. Press 'M' to enter management
2. Select torrents
3. Repair or Delete
4. ✅ Prompted: "Continue managing? (y/n)"
   - Press 'y': Refreshes list, stays in management
   - Press 'n': Returns to monitoring
5. Repeat steps 2-4 until cleanup complete
6. Press 'n' when done
```

---

## Example Session

**Scenario:** You have 70 unrepairable torrents and want to:
1. Delete all "infringing torrent" items
2. Delete all "invalid file ids" items  
3. Repair all "repair failed, download status: error" items

### Session Flow

```
======================================================================
  UNREPAIRABLE TORRENT MANAGEMENT
======================================================================
Found 70 unrepairable torrent(s)
...
Currently selected: 0 torrent(s)

Enter command: 3,16,35,37,50,55,56,59,60,63,64,65,70
# Selected 13 "infringing torrent" items

Enter command: D
Type 'DELETE' to confirm deletion of 13 torrents: DELETE
Deleting torrents...
Deleted 13 / 13 torrent(s)
Press any key to continue...

Continue managing unrepairable torrents? (y/n): y
Refreshing unrepairable torrent list...

======================================================================
  UNREPAIRABLE TORRENT MANAGEMENT
======================================================================
Found 57 unrepairable torrent(s)
# List updated - 13 deleted items gone!
...

Enter command: 62
# Select the "1080p - invalid file ids" item (new numbering)

Enter command: D
Type 'DELETE' to confirm deletion of 1 torrents: DELETE
Deleting torrents...
Deleted 1 / 1 torrent(s)
Press any key to continue...

Continue managing unrepairable torrents? (y/n): y
Refreshing unrepairable torrent list...

======================================================================
  UNREPAIRABLE TORRENT MANAGEMENT
======================================================================
Found 56 unrepairable torrent(s)
...

Enter command: 1,2,5,9,11-15,17-19,21,23,25-31
# Select all "repair failed, download status: error" items

Enter command: R
Type 'yes' to confirm repair of 20 torrents: yes
Triggering repairs...
Repair triggered for 20 / 20 torrent(s)
Press any key to continue...

Continue managing unrepairable torrents? (y/n): n
# Done! Return to monitoring

[2025-12-04 22:30:00] [INFO] Next check in 30 minutes...
```

---

## Key Benefits

### 1. **No Context Loss**
Stay in management mode throughout your entire cleanup session without losing track of where you were.

### 2. **Live Updates**
The torrent list refreshes after each action, showing updated counts and renumbered items.

### 3. **Batch Processing**
Handle multiple types of failures in one session:
- First pass: Delete infringing
- Second pass: Delete invalid
- Third pass: Repair errors
- Fourth pass: Handle not cached

### 4. **Flexibility**
Exit anytime by pressing 'n' when prompted, or use 'Q' command to quit immediately.

---

## Prompt Details

### After Repair
```
Repair triggered for X / Y torrent(s)
Press any key to continue...
[Press any key]

Continue managing unrepairable torrents? (y/n): _
```

### After Delete
```
Deleted X / Y torrent(s)
Press any key to continue...
[Press any key]

Continue managing unrepairable torrents? (y/n): _
```

### Options
- **'y' or 'Y'**: Refresh list and continue managing
- **'n' or 'N' or anything else**: Return to monitoring mode

---

## What Gets Refreshed

When you press 'y' to continue:

1. ✅ **Fetches latest data** from Zurg's `/manage/?state=status_cannot_repair` endpoint
2. ✅ **Rebuilds torrent list** with current unrepairable torrents
3. ✅ **Resets selection** (all checkboxes unchecked)
4. ✅ **Renumbers items** (if count changed)
5. ✅ **Shows updated count** in header

### Example
**Before delete:**
```
Found 70 unrepairable torrent(s)
 1. [ ] Torrent A
 2. [ ] Torrent B
 3. [ ] Torrent C
...
```

**After deleting #2, refresh shows:**
```
Found 69 unrepairable torrent(s)
 1. [ ] Torrent A
 2. [ ] Torrent C  ← Renumbered!
...
```

---

## Edge Cases

### All Torrents Cleaned Up
```
Continue managing unrepairable torrents? (y/n): y
Refreshing unrepairable torrent list...
No unrepairable torrents found.
Press any key to return to monitoring...
```
Automatically exits since there's nothing left to manage.

### API Failure During Refresh
If the refresh fails, the old list remains displayed and you can:
- Try again (press 'y' next time)
- Exit to monitoring (press 'n')

---

## Tips

### Efficient Workflow
1. **Identify patterns** in the initial list
2. **Group similar reasons** in your mind
3. **Process in order**: Delete first, then repair
4. **Use ranges** for consecutive items of same type
5. **Refresh frequently** to see progress

### When to Exit
Press 'n' to return to monitoring when:
- ✅ Cleanup complete
- ✅ Need to wait for repairs to process
- ✅ Want to let monitoring run for a while
- ✅ Finished your session

### When to Continue
Press 'y' to stay in management when:
- ✅ More torrents to process
- ✅ Different failure reasons to handle
- ✅ Want to see immediate results of actions
- ✅ Batch processing multiple categories

---

## Commands Reference

```
[#] [#-#] [#,#]  Toggle selection (single, range, or list)
[A]              Select All
[N]              Select None
[R]              Repair selected torrents
[D]              Delete selected torrents
[Q]              Quit immediately (no prompt)

After action:
[y]              Continue managing (refresh list)
[n]              Return to monitoring
```

---

**Now you can clean up your entire unrepairable torrent list in one session!** 🎯
