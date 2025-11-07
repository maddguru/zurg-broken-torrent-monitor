# Changelog

All notable changes to the Zurg Broken Torrent Monitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.2.0] - 2025-11-06

### Added
- **Total Torrent Statistics Display**: Complete overview of your entire torrent library
  - Shows total torrent count
  - Displays OK torrents with percentage (healthy torrents)
  - Shows broken torrents with percentage
  - Shows under-repair torrents with percentage
- **New Function**: `Get-ZurgTotalTorrentStats` - Fetches and counts all torrents from Zurg
- **Enhanced Context**: Percentages help assess library health at a glance
- **Color-Coded Health Indicators**: Visual feedback for library status

### Changed
- Updated `$Script:Stats.CurrentCheck` to include `TotalTorrents` and `OkTorrents` fields
- Enhanced `Show-CheckSummary` to display torrent statistics section
- Improved visual hierarchy in check summary output

### Technical Details
- Adds one additional API call to `/manage/` per check cycle
- Uses efficient regex pattern matching for unique hash extraction
- Minimal performance impact (<1 second per check for large libraries)

---

## [2.1.0] - 2025-11-05

### Added
- **Under Repair Monitoring**: Now tracks torrents in "under repair" state
- **Re-trigger for Under Repair**: Automatically re-triggers repairs for stuck torrents
- **Enhanced Comparison Logic**: Shows 5 categories of torrent status changes:
  - Successfully Repaired
  - Moved to Repair
  - Still Broken
  - Still Under Repair
  - New Broken
- **Repair Success Rate**: Displays percentage of successful repairs between checks
- **Comprehensive Status Tracking**: Better visibility into repair progress

### Changed
- Improved comparison display between consecutive checks
- Enhanced statistics tracking for repair outcomes
- Better color coding for different torrent states

### Fixed
- Removed "Repairs Failed" tracking (repairs don't fail at API level)

---

## [2.0.0] - 2025-11-05

### Added
- **Direct State Filtering**: Uses Zurg's `/manage/?state=status_broken` endpoint
- **Accurate Torrent Detection**: Matches exactly what web UI shows
- **Multiple Parsing Methods**: Robust HTML parsing with fallback patterns
- **Torrent Name Extraction**: Properly extracts and displays torrent names
- **Comparison Between Checks**: Tracks which torrents got fixed vs still broken
- **Statistics Display**: Shows overall statistics across all monitoring sessions

### Changed
- Complete rewrite of torrent detection logic
- Switched from parsing all torrents to using filtered API endpoints
- Improved HTML parsing with multiple fallback patterns
- Better error handling and logging

### Fixed
- **Critical**: Script now finds the same torrents as web UI (was finding different ones)
- **Critical**: Fixed repair API endpoint from `/torrents/{hash}/repair` to `/manage/{hash}/repair`
- Fixed torrent names showing as "Unknown"
- Fixed PowerShell encoding issues causing parse errors
- Fixed backtick and string terminator errors

---

## [1.0.0] - 2025-10-28

### Added
- Initial release
- Basic broken torrent detection
- Automatic repair triggering
- Configurable check intervals
- Color-coded console output
- Comprehensive logging
- Basic authentication support
- Run-once or continuous monitoring modes
- Verbose debugging option

### Known Issues
- Script may find different torrents than web UI (fixed in v2.0.0)
- Repair endpoint returns 404 errors (fixed in v2.0.0)
- Torrent names not properly extracted (fixed in v2.0.0)

---

## Version History Summary

| Version | Date | Key Feature |
|---------|------|-------------|
| **2.2.0** | 2025-11-06 | Total torrent statistics with health percentages |
| **2.1.0** | 2025-11-05 | Under repair monitoring and enhanced comparison |
| **2.0.0** | 2025-11-04 | Fixed torrent detection and repair endpoints |
| **1.0.0** | 2025-10-28 | Initial release with basic monitoring |

---

## Upgrade Notes

### From v2.1 to v2.2
- **No breaking changes** - drop-in replacement
- **New statistics display** - automatically shows on next check
- **No configuration changes needed**

### From v2.0 to v2.1
- **No breaking changes** - drop-in replacement
- **Enhanced tracking** - automatically begins on next check
- **No configuration changes needed**

### From v1.x to v2.0
- **No breaking changes** - drop-in replacement
- **Better accuracy** - will now find correct torrents
- **Working repairs** - repair endpoint now functional
- **No configuration changes needed**

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to contribute to this project.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
