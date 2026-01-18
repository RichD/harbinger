# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
