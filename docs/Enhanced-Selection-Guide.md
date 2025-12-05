# Enhanced Selection in Unrepairable Torrent Management

## Overview
The management interface now supports **advanced bulk selection** with ranges and comma-separated lists, making it easy to select multiple torrents based on their failure reasons.

---

## Selection Syntax

### Single Number
Select/deselect one torrent:
```
5
```
Toggles torrent #5

### Range
Select/deselect a consecutive range:
```
1-10
```
Toggles torrents 1 through 10

### Comma-Separated List
Select/deselect specific torrents:
```
1,5,10,15
```
Toggles torrents 1, 5, 10, and 15

### Mixed (Ranges + Individual)
Combine ranges and individual numbers:
```
1-5,10,15-20,25
```
Toggles:
- 1, 2, 3, 4, 5
- 10
- 15, 16, 17, 18, 19, 20
- 25

---

## Real-World Examples

### Example: Delete All "infringing torrent" Items

Looking at your list:
```
 3. [ ] [ Torrent911.net ] South Park S23...
       Reason: infringing torrent
16. [ ] Matlock.2024.S01.Complete...
       Reason: infringing torrent
35. [ ] Yellowstone.2018.S01-S05...
       Reason: infringing torrent
37. [ ] Tulsa King (2022) Season 2...
       Reason: infringing torrent
...
```

**Selection:** `3,16,35,37,50,55,56,59,60,63,64,65,70`

Then press **[D]** to delete them all at once.

---

### Example: Select "not cached" Items in a Range

If torrents 4-8 and 40-44 are all "not cached (restricted to cached)":

**Selection:** `4-8,40-44`

Then decide to:
- Press **[R]** to attempt repair (might become cached later)
- Press **[D]** to delete them

---

### Example: Select "repair failed" Items

If you want to delete all "repair failed, download status: error" items scattered throughout:

**Selection:** `1,2,5,9,11-15,17-19,21,23,25-31,33,34,36,38,39,45,48,49,51-54,57,58,61,66-69`

---

## Tips

### Finding Patterns
1. Look at the output and identify failure reasons
2. Note the numbers for each reason
3. Group consecutive numbers into ranges
4. Combine with commas

### Validation
The script validates:
- Numbers must be between 1 and total count (70 in your case)
- Ranges must have start ≤ end
- Invalid input shows an error message

### Toggle Behavior
All selection methods **toggle** the current state:
- If unchecked `[ ]`, it becomes checked `[X]`
- If checked `[X]`, it becomes unchecked `[ ]`

So you can:
1. Select all with **[A]**
2. Deselect unwanted ones with ranges/lists
3. Or build selection incrementally

---

## Commands Reference

```
[#] [#-#] [#,#]  Toggle selection (single, range, or list)
[A]              Select All
[N]              Select None
[R]              Repair selected torrents
[D]              Delete selected torrents
[Q]              Quit and return to monitoring
```

---

## Example Session

**Goal:** Delete all infringing torrents and repair all download errors

**Step 1:** Select infringing torrents
```
Enter command: 3,16,35,37,50,55,56,59,60,63,64,65,70
Currently selected: 13 torrent(s)
```

**Step 2:** Delete them
```
Enter command: D
Type 'DELETE' to confirm deletion of 13 torrents: DELETE
✓ Deleted 13 torrents
```

**Step 3:** Select repair failed torrents (after refresh)
```
Enter command: 1-2,5,9,11-15,17-19
Currently selected: 14 torrent(s)
```

**Step 4:** Attempt repair
```
Enter command: R
Type 'yes' to confirm repair of 14 torrents: yes
✓ Triggered repair for 14 torrents
```

---

## Error Messages

**Invalid range:**
```
Enter command: 10-5
Invalid range: 10-5 (start must be <= end)
```

**Out of bounds:**
```
Enter command: 100
Invalid number: 100 (valid: 1-70)
```

**Invalid format:**
```
Enter command: 1-5-10
Invalid format: 1-5-10
```

---

**This enhancement makes managing 70+ unrepairable torrents much more efficient!** 🎯
