# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-01-18

### Added
- **PostgreSQL detection**: Detects PostgreSQL versions from Rails projects
  - Checks `config/database.yml` for `adapter: postgresql`
  - Runs `psql --version` for local databases
  - Falls back to `pg` gem version from `Gemfile.lock`
  - Skips shell commands for remote databases (AWS RDS, etc.) to avoid client vs server version mismatch
- **MySQL detection**: Detects MySQL versions from Rails projects
  - Supports both `mysql2` and `trilogy` adapters (Rails 7.1+)
  - Runs `mysql --version` or `mysqld --version` for local databases
  - Falls back to gem version from `Gemfile.lock`
  - Smart remote database detection
- **Rescan command**: `harbinger rescan` to bulk update all tracked projects
  - Updates all projects with latest detected versions
  - Automatically removes projects with missing directories
  - `--verbose` flag for detailed output
  - Progress counter shows scan status
- **Enhanced dashboard**: PostgreSQL and MySQL columns in `harbinger show`
  - Database versions displayed in table
  - Database EOL dates included in status calculation
  - Dashboard prioritizes database EOL issues
- **Database EOL tracking**: Fetches EOL data for PostgreSQL and MySQL
  - `harbinger update` now fetches database EOL data
  - Supports major-only version cycles (PostgreSQL) and major.minor cycles (MySQL)
- **Multi-database support**: Handles Rails 6+ multi-database configurations

### Changed
- `EolFetcher` now supports major-only version matching (PostgreSQL uses "16", not "16.11")
- Scan output includes database versions with aligned formatting
- Status calculation includes database EOL dates

### Technical
- Added `DatabaseDetector` abstract base class for database detection
- Added `PostgresDetector` with local/remote detection (116 total tests passing)
- Added `MysqlDetector` with trilogy and mysql2 support
- Test fixtures for various database.yml configurations
- Remote database detection to avoid shell command mismatches
- Support for single and multi-database Rails configurations

## [0.2.0] - 2026-01-18

### Added
- **Project tracking**: Save and track multiple projects with `--save` flag
- **Dashboard view**: `harbinger show` command displays all tracked projects in a table
- **Recursive scanning**: `--recursive` flag to scan all subdirectories with Gemfiles
- **Config management**: Projects stored in `~/.harbinger/config.yml`
- **Bulk operations**: Scan entire directories like `~/Projects` and save all at once
- **Enhanced UI**: TTY::Table for beautiful table formatting in dashboard
- **Color-coded dashboard**: Red for EOL projects, yellow for ending soon, green for current
- **Smart sorting**: Dashboard prioritizes EOL projects at the top

### Changed
- `scan` command now uses `--path` flag instead of positional argument for consistency
- ConfigManager API uses extensible `versions: {}` hash for future product support
- Enhanced test coverage (52 passing tests)

### Technical
- Added ConfigManager with YAML persistence
- ISO8601 timestamp format for YAML safety
- Extensible architecture for future language/database support

## [0.1.0] - 2026-01-18

### Added
- Ruby version detection from `.ruby-version`, `Gemfile`, and `Gemfile.lock`
- Rails version detection from `Gemfile.lock`
- EOL data fetching from endoflife.date API
- Smart caching with 24-hour expiry
- CLI commands:
  - `harbinger scan [PATH]` - Scan project and show EOL status
  - `harbinger update` - Force refresh EOL data
  - `harbinger version` - Show harbinger version
- Color-coded status display:
  - Red: Already EOL or <30 days remaining
  - Yellow: <6 months remaining
  - Green: >6 months remaining
- Product detection with helpful guidance when version not specified
- Comprehensive test suite (36 tests)
- Automatic EOL data fetch on first scan (zero configuration)

### Technical
- Built with Thor for CLI framework
- HTTParty for HTTP requests
- TTY gems for terminal UI
- RSpec for testing
- RuboCop for linting
