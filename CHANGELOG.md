# Changelog

All notable changes to the Zurg Broken Torrent Monitor project will be documented in this file.

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
