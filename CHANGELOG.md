# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-31

### Added
- Comparison with previous check showing:
  - Successfully repaired torrents
  - Still broken torrents
  - New broken torrents
  - Repair success rate percentage
- Improved HTML parsing with multiple fallback patterns
- Better torrent name extraction from Zurg's web interface
- Color-coded output for better readability
- Comprehensive logging with timestamps
- Support for basic authentication

### Changed
- Now fetches `/manage/?state=status_broken` directly for exact match with web UI
- Updated repair endpoint to `/manage/{hash}/repair` (correct endpoint)
- Simplified repair tracking (removed failure tracking)
- Improved error handling and connection testing

### Fixed
- PowerShell encoding issues (UTF-8 BOM)
- Variable reference errors in string interpolation
- Torrent name extraction now works correctly
- Script now finds exact same torrents as Zurg's web interface

### Removed
- Repair failure tracking (simplified logic)
- Unnecessary complexity in torrent detection

## [1.0.0] - 2024-XX-XX

### Added
- Initial release
- Basic broken torrent detection
- Automatic repair triggering
- Configurable check intervals
- Log file support
