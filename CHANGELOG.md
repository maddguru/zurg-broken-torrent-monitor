# Changelog

All notable changes to the Zurg Broken Torrent Monitor project will be documented in this file.

## [2.5.2] - 2025-12-11

### Added
- **Health Verification System**: Scan all "OK" torrents to detect status mismatches
  - Startup verification (optional, controlled by AutoVerify setting)
  - Manual verification via `V` key anytime during monitoring
  - Live progress bar with ETA, memory usage, and mismatch count
  - Detects torrents where State ≠ Active or File States ≠ OK
- **Persistent Settings**: AutoRepair and AutoVerify settings saved to JSON file
  - Settings file: `zurg-monitor-settings.json`
  - Remembers preferences between script restarts
  - Toggle with `T` (AutoRepair) or `TV` (AutoVerify) - changes save automatically
- **Memory Optimization**: Improved handling for large libraries (5000+ torrents)
  - ArrayList usage instead of array concatenation
  - Automatic garbage collection after verification and each cycle
  - Memory usage displayed in status bar and statistics
  - Mismatch list capped at 100 entries
- **New Parameters**:
  - `-SettingsFile`: Custom path for settings JSON
  - `-SkipStartupVerification`: Skip startup verification even if enabled
  - `-VerifyDelayMs`: Delay between torrent checks (default: 50ms)
- **New Hotkeys**:
  - `V` during wait: Run health verification
  - `TV` in Management UI: Toggle AutoVerify
  - `FM` in Management UI: Filter to Mismatch torrents only

### Fixed
- False positive mismatch detection - now correctly parses Zurg's HTML structure
- Script crash when pressing keys after wait timer expired (negative progress bar)
- Memory output spam from cleanup function (raw hashtable display)
- Negative TimeSpan display now shows "0s" instead of crashing
- Unrecognized keypresses during wait now handled gracefully

### Changed
- Verification runs only on startup (if enabled) - no longer every monitoring cycle
- Memory values displayed with 2 decimal places (e.g., "45.23 MB")
- Wait screen shows memory usage
- Statistics show settings file path and memory usage

## [2.4.0] - 2025-12-10

### Added
- **Unified Torrent Management Center**: Single interface for ALL torrent types
  - Broken torrents displayed with `[BRK]` badge (Yellow)
  - Under Repair torrents displayed with `[REP]` badge (Cyan)
  - Unrepairable torrents displayed with `[BAD]` badge (Red)

- **Advanced Filtering System**
  - `FB` - Filter Broken only
  - `FU` - Filter Under Repair only
  - `FC` - Filter Unrepairable only
  - `F*` - Show All
  - `FS` - Search by name
  - `FR` - Filter by reason
  - `FX` - Clear all filters

- **Bulk Select by Reason**: `BR` command selects all torrents matching a pattern

- **Live AutoRepair Toggle**: `T` command toggles AutoRepair without restart

- **Hotkeys During Wait Period**
  - Press `M` anytime to enter Management
  - Press `S` anytime to view Statistics

### Changed
- Management UI now accessible anytime during monitoring
- AutoRepair is now a runtime-toggleable setting
- Statistics display includes AutoRepair status

## [2.3.0] - 2025-12-05

### Added
- Unrepairable Torrent Management with interactive UI
- Enhanced Bulk Selection (ranges, comma-separated, mixed)
- Continuous Management Mode
- Auto-Repair Control parameter
- Deletion statistics tracking

### Fixed
- Hashtable access bug (18 locations)
- Array initialization issues
- HTML parsing improvements

## [2.2.1] - 2025-11-13

### Fixed
- Critical array unwrapping bug

## [2.2.0] - 2025-11-06

### Added
- Total torrent statistics with health percentages

## [2.1.0] - 2025-11-05

### Added
- Under repair monitoring
- Enhanced comparison logic
- Repair success rate calculation

## [2.0.0] - 2025-11-05

### Fixed
- Torrent detection using correct endpoints
- Repair API endpoint correction
- HTML parsing improvements
