# Changelog

All notable changes to the Zurg Broken Torrent Monitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.3.0] - 2025-12-05

### Added
- **Unrepairable Torrent Management**: Complete interactive system for handling torrents that cannot be automatically repaired
  - New function `Get-ZurgUnrepairableTorrents` fetches from `/manage/?state=status_cannot_repair`
  - New function `Invoke-TorrentDelete` permanently removes torrents from Zurg
  - New function `Show-UnrepairableManagement` provides full-featured management UI
  - Displays full torrent names, hashes, and detailed failure reasons
  - Interactive management mode activated with 'M' key press
  - Checkbox-based selection interface for individual control
  
- **Enhanced Bulk Selection**: Advanced selection syntax for efficient batch operations
  - Single number: `5` toggles one torrent
  - Range selection: `1-10` toggles consecutive torrents
  - Comma-separated: `1,5,10,15` toggles specific torrents
  - Mixed syntax: `1-5,10,15-20,25` combines ranges and individuals
  - Validation and error handling for all input types
  
- **Continuous Management Mode**: Stay in management interface without exiting
  - After repair/delete, prompted: `Continue managing unrepairable torrents? (y/n)`
  - Press 'y' to refresh torrent list and continue managing
  - Press 'n' to return to monitoring mode
  - Enables complete cleanup in single session
  - Live updates show immediate results of actions
  
- **Auto-Repair Control**: New parameter for safety and flexibility
  - Parameter: `-AutoRepair [bool]` with default value `$false`
  - `$true`: Automatically triggers repairs for broken/under-repair torrents
  - `$false`: Monitoring only mode, manual control via management interface
  - Startup message shows current mode
  - Applied to both broken and under-repair torrent processing
  
- **Statistics Tracking**: Comprehensive tracking of manual and automatic actions
  - New metric: `DeletionsTriggered` tracks manual deletions
  - `RepairsTriggered` now includes both automatic and manual repairs
  - Statistics persist across entire monitoring session
  - Displayed in overall statistics on exit
  
- **Safety Features**: Multiple confirmation prompts
  - Repair: Must type `yes` to confirm
  - Delete: Must type `DELETE` (exact, case-sensitive) to confirm
  - Prevents accidental bulk operations
  - Clear warning messages before destructive actions

### Changed
- **Default Behavior**: Auto-repair now disabled by default (`$false`)
  - Prioritizes safety over automation
  - Users must explicitly enable auto-repair
  - Monitoring-only mode encourages manual review
  
- **Check Summary Display**: Enhanced unrepairable torrent presentation
  - Shows full torrent names (not truncated)
  - Displays complete failure reasons
  - Lists all unrepairable torrents with proper formatting
  - Added "Press 'M'" prompt when unrepairable torrents detected
  
- **Management Interface**: Complete redesign for usability
  - Professional box-drawing layout
  - Color-coded sections (Red headers, Yellow names, Gray hashes)
  - Clear command reference always visible
  - Real-time selection counter
  - Comprehensive help text

### Fixed
- **Critical - Hashtable Access Bug**: Fixed 18 locations where dot notation caused single-character display
  - Changed all `$torrent.Name` to `$torrent['Name']` (bracket notation)
  - Fixed both storage and display sections
  - Prevents PowerShell from treating hashtable as string
  - Resolves "P" and "r" display issue
  
- **Critical - Array Initialization**: Added proper initialization for unrepairable data arrays
  - Added `UnrepairableFound`, `UnrepairableHashes`, `UnrepairableNames`, `UnrepairableReasons` to `CurrentCheck` structure
  - Prevents PowerShell from creating strings instead of arrays on `+=` operation
  - Ensures data is properly stored and retrievable
  
- **Critical - Brace Imbalance**: Fixed multiple structural issues
  - Added missing closing brace for Start-MonitoringLoop function
  - Fixed under-repair if statement missing closing brace
  - Removed extra closing braces in Show-CheckSummary
  - Fixed unrepairable section incorrectly nested inside under-repair section
  - Final balance: 193 opening, 193 closing braces
  
- **HTML Parsing**: Updated to use correct attributes
  - Changed name extraction from link text to `data-name` attribute
  - Changed reason extraction from "Broken (reason: ...)" to `title` attribute of state badge
  - Handles all Real-Debrid failure message formats
  - Supports special characters and complex naming
  
- **Parameter Syntax**: Fixed PowerShell parameter list errors
  - Added missing comma after `$VerboseLogging` parameter
  - Removed extra trailing comma before closing parenthesis
  - Script now parses without errors
  
- **Nesting Issue**: Corrected unrepairable section placement
  - Moved unrepairable detection from inside under-repair if block
  - Now executes independently when unrepairable torrents exist
  - Prevents skipping when no under-repair torrents present
  
- **Error Check Logic**: Updated to include unrepairable torrents
  - Changed from checking only broken/under-repair to all three states
  - Prevents false "API failed" messages when only unrepairable exist
  - More accurate error detection

### Technical Improvements
- **Code Organization**: Better structure and separation of concerns
  - All management functions clearly separated
  - Consistent error handling patterns
  - Improved code comments and documentation
  
- **PowerShell Best Practices**: Follows recommended patterns
  - Proper hashtable access throughout
  - Correct array initialization
  - UTF-8 BOM encoding for special characters
  - UseBasicParsing for web requests
  
- **Performance**: Optimized operations
  - Minimal API calls (one per state check)
  - Efficient array operations
  - Fast UI refresh in management mode
  - No memory leaks detected in 24+ hour testing

### Security
- **Safe Defaults**: Monitoring-only mode prevents unintended automation
- **Confirmation Prompts**: All destructive actions require explicit confirmation
- **Credential Handling**: Consistent authentication pattern throughout
- **Logging**: All actions logged with timestamps for audit trail

---

## [2.2.1] - 2025-11-13

### Fixed
- **Critical:** Fixed PowerShell array unwrapping issue causing false "API failed" errors
  - When library had 0 broken/under repair torrents, function returned empty array `@()`
  - PowerShell automatically unwrapped empty arrays to `$null`
  - Script incorrectly detected this as API failure
  - Solution: Added comma operator (`,`) to preserve empty arrays in return statements
- Healthy libraries (0 broken torrents) now correctly show SUCCESS message instead of ERROR

### Technical Details
- Changed line 255: `return $torrents` → `return ,$torrents`
- One character fix that resolves the core issue
- No configuration changes required
- No breaking changes

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
- **Enhanced Comparison Logic**: Shows 5 categories of torrent status changes
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
- **Critical**: Script now finds the same torrents as web UI
- **Critical**: Fixed repair API endpoint from `/torrents/{hash}/repair` to `/manage/{hash}/repair`
- Fixed torrent names showing as "Unknown"
- Fixed PowerShell encoding issues causing parse errors

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

---

## Version History Summary

| Version | Date | Key Feature |
|---------|------|-------------|
| **2.3.0** | 2025-11-26 | Unrepairable torrent management |
| **2.2.1** | 2025-11-13 | Critical fix: Array unwrapping bug |
| **2.2.0** | 2025-11-06 | Total torrent statistics |
| **2.1.0** | 2025-11-05 | Under repair monitoring |
| **2.0.0** | 2025-11-05 | Fixed detection & repair |
| **1.0.0** | 2025-10-28 | Initial release |

---

## Future Roadmap

### Potential Features (v2.4+)
- [ ] Webhook/Discord notifications
- [ ] Email alerts for persistent issues
- [ ] CSV export of unrepairable torrents
- [ ] Automatic deletion of long-term unrepairable
- [ ] Historical trend tracking
- [ ] Web dashboard interface
- [ ] Multiple Zurg instance support

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to contribute to this project.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
