# Contributing to Zurg Broken Torrent Monitor

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## 🐛 Reporting Bugs

Before submitting a bug report:
1. Check if the issue already exists in [GitHub Issues](https://github.com/maddguru/zurg-broken-torrent-monitor/issues)
2. Test with the latest version of the script
3. Enable verbose logging (`-VerboseLogging`) to get detailed output

When submitting a bug report, include:
- **PowerShell version:** `$PSVersionTable.PSVersion`
- **Zurg version:** Check your Zurg installation
- **Script version:** See CHANGELOG.md
- **Error message:** Full error output
- **Log file:** Relevant portions of the log file
- **Steps to reproduce:** Clear steps to reproduce the issue

## 💡 Suggesting Features

Feature requests are welcome! Please:
1. Check if it's already requested in Issues
2. Explain the use case and benefit
3. Provide examples if possible

## 🔧 Pull Requests

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/maddguru/zurg-broken-torrent-monitor.git
   ```
3. Create a branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Coding Guidelines

- **PowerShell best practices:** Follow PowerShell style guidelines
- **Comments:** Add comments for complex logic
- **Error handling:** Include try-catch blocks for API calls
- **Logging:** Use appropriate log levels (INFO, WARN, ERROR, SUCCESS, DEBUG)
- **Testing:** Test your changes thoroughly before submitting

### Code Style

- Use 4 spaces for indentation
- Use descriptive variable names
- Keep functions focused and single-purpose
- Add parameter validation where appropriate

### Testing Checklist

Before submitting a PR, test:
- [ ] Script runs without errors
- [ ] Connects to Zurg successfully
- [ ] Detects broken torrents correctly
- [ ] Triggers repairs successfully
- [ ] Comparison logic works between checks
- [ ] Log file is created and populated
- [ ] Verbose logging works (if changed)
- [ ] `-RunOnce` parameter works

### Commit Messages

Use clear, descriptive commit messages:
- `feat: Add feature description`
- `fix: Fix bug description`
- `docs: Update documentation`
- `refactor: Refactor code description`
- `test: Add or update tests`

### Submitting

1. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
2. Create a Pull Request on GitHub
3. Describe your changes clearly
4. Link any related issues

## 📝 Documentation

Documentation improvements are always welcome! This includes:
- README updates
- Code comments
- Examples
- Troubleshooting guides

## 🤔 Questions?

Feel free to:
- Open a [Discussion](https://github.com/maddguru/zurg-broken-torrent-monitor/discussions)
- Ask in an existing Issue
- Reach out to maintainers

## 📜 Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Keep discussions on-topic

## 🙏 Thank You!

Your contributions help make this tool better for everyone!
