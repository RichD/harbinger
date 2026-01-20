# Harbinger

**Track End-of-Life dates for your tech stack and stay ahead of deprecations.**

Harbinger is a CLI tool that scans your Ruby, Rails, Python, Node.js, Rust, Go, PostgreSQL, MySQL, Redis, and MongoDB versions, and warns you about upcoming EOL (End-of-Life) dates. Never get caught off-guard by unsupported dependencies again.

## Features

- 🔍 **Auto-detects versions** from `.ruby-version`, `Gemfile`, `Gemfile.lock`, `.nvmrc`, `.python-version`, `pyproject.toml`, `package.json`, `rust-toolchain`, `Cargo.toml`, `go.mod`, `config/database.yml`, and `docker-compose.yml`
- 🐘 **Database detection** for PostgreSQL, MySQL, Redis, and MongoDB
- 🌐 **Multi-language support** - Ruby, Python, Node.js, Rust, Go
- 📊 **Ecosystem-grouped dashboard** - Projects organized by language ecosystem with relevant components only
- 📅 **Fetches EOL data** from [endoflife.date](https://endoflife.date)
- 🎨 **Color-coded warnings** (red: already EOL, yellow: <6 months, green: safe)
- ⚡ **Smart caching** (24-hour cache, works offline after first fetch)
- 🔄 **Bulk operations** with `--recursive` scan and `rescan` command
- 📤 **Export to JSON/CSV** for reporting and automation
- 🚀 **Zero configuration** - just run `harbinger scan`

## Installation

### Homebrew (macOS)

```bash
brew tap RichD/harbinger
brew install stackharbinger
```

### RubyGems

```bash
gem install stackharbinger
```

Or add to your Gemfile:

```ruby
gem 'stackharbinger'
```

The command is `harbinger` (shorter to type).

## Usage

### Scan a project

```bash
# Scan current directory
harbinger scan

# Scan specific project
harbinger scan --path ~/Projects/my-rails-app

# Save project for tracking
harbinger scan --save

# Scan all Ruby projects in a directory recursively
harbinger scan --path ~/Projects --recursive --save
```

**Example output:**

```
Scanning /Users/you/Projects/my-app...

Detected versions:
  Ruby:       3.2.0
  Rails:      7.0.8
  PostgreSQL: 16.11

Fetching EOL data...

Ruby 3.2.0:
  EOL Date: 2026-03-31
  Status:   437 days remaining

Rails 7.0.8:
  EOL Date: 2025-06-01
  Status:   ALREADY EOL (474 days ago)

PostgreSQL 16.11:
  EOL Date: 2028-11-09
  Status:   1026 days remaining
```

### View tracked projects

```bash
# Show dashboard of all tracked projects
harbinger show

# Filter to specific project(s) by name or path
harbinger show budget
harbinger show job

# Show project paths with verbose mode
harbinger show -v
harbinger show job --verbose
```

### Export data

```bash
# Export to JSON (stdout)
harbinger show --format json

# Export to CSV (stdout)
harbinger show --format csv

# Save to file
harbinger show --format json -o report.json
harbinger show --format csv --output eol-report.csv

# Export filtered projects
harbinger show myproject --format json
```

**Example output:**

```
Tracked Projects (12)

Ruby Ecosystem (7)
================================================================================
┌─────────────────┬───────┬──────────┬────────────┬───────┬─────────────────┐
│ Project         │ Ruby  │ Rails    │ PostgreSQL │ Redis │ Status          │
├─────────────────┼───────┼──────────┼────────────┼───────┼─────────────────┤
│ shop-api        │ 3.2.0 │ 6.1.7    │ 15.0       │ -     │ ✗ Rails EOL     │
│ blog-engine     │ 3.3.0 │ 7.0.8    │ 16.0       │ 7.0   │ ✗ Rails EOL     │
│ analytics-app   │ 3.3.0 │ 8.0.1    │ 16.0       │ -     │ ✓ Current       │
│ admin-portal    │ 3.3.0 │ 8.0.4    │ 16.11      │ 7.2   │ ✓ Current       │
│ billing-service │ 3.4.1 │ 8.1.0    │ 17.0       │ -     │ ✓ Current       │
└─────────────────┴───────┴──────────┴────────────┴───────┴─────────────────┘

Python Ecosystem (3)
================================================================================
┌──────────────┬────────┬────────────┬─────────┐
│ Project      │ Python │ PostgreSQL │ Status  │
├──────────────┼────────┼────────────┼─────────┤
│ ml-pipeline  │ 3.11   │ 16.0       │ ✓ Current │
│ data-scraper │ 3.12   │ -          │ ✓ Current │
│ ai-worker    │ 3.13   │ 15.0       │ ✓ Current │
└──────────────┴────────┴────────────┴─────────┘

Node.js Ecosystem (2)
================================================================================
┌───────────────┬─────────┬────────────┬──────────────────────┐
│ Project       │ Node.js │ PostgreSQL │ Status               │
├───────────────┼─────────┼────────────┼──────────────────────┤
│ frontend-app  │ 18.0    │ -          │ ⚠ Node.js ending soon │
│ realtime-api  │ 22.0    │ 16.0       │ ✓ Current            │
└───────────────┴─────────┴────────────┴──────────────────────┘
```

Projects are grouped by their primary programming language ecosystem. Each ecosystem only displays relevant components (e.g., Python projects don't show Ruby/Rails columns).

### Re-scan all tracked projects

```bash
# Update all tracked projects with latest versions
harbinger rescan

# Show detailed output for each project
harbinger rescan --verbose
```

### Remove a project

```bash
# Remove a project from tracking
harbinger remove my-project
```

### Update EOL data

```bash
# Force refresh EOL data from endoflife.date
harbinger update
```

### Show version

```bash
harbinger version
```

## How It Works

1. **Detection**: Harbinger looks for version info in your project:
   - Ruby: `.ruby-version`, `Gemfile` (`ruby "x.x.x"`), `Gemfile.lock` (RUBY VERSION)
   - Rails: `Gemfile.lock` (rails gem)
   - Python: `.python-version`, `pyproject.toml`, `docker-compose.yml`, or `python --version`
   - Node.js: `.nvmrc`, `.node-version`, `package.json` engines, `docker-compose.yml`, or `node --version`
   - Rust: `rust-toolchain`, `rust-toolchain.toml`, `Cargo.toml` (rust-version), `docker-compose.yml`, or `rustc --version`
   - Go: `go.mod`, `go.work`, `.go-version`, `docker-compose.yml`, or `go version`
   - PostgreSQL: `config/database.yml` (adapter check) + `psql --version` or `pg` gem
   - MySQL: `config/database.yml` (mysql2/trilogy adapter) + `mysql --version` or gem version
   - Redis: `docker-compose.yml` + `redis-server --version` or `redis` gem
   - MongoDB: `docker-compose.yml` + `mongod --version` or `mongoid`/`mongo` gem

2. **EOL Data**: Fetches official EOL dates from [endoflife.date](https://endoflife.date) API

3. **Caching**: Stores data in `~/.harbinger/data/` for 24 hours (works offline)

4. **Analysis**: Compares your versions against EOL dates and color-codes the urgency

## Version Detection

### Ruby Detection Priority

1. `.ruby-version` file (highest priority)
2. `ruby "x.x.x"` declaration in Gemfile
3. `RUBY VERSION` section in Gemfile.lock

If Harbinger detects a Ruby project but no version:
```
Ruby:  Present (version not specified - add .ruby-version or ruby declaration in Gemfile)
```

### Rails Detection

Parses `Gemfile.lock` for the rails gem version.

### PostgreSQL Detection

1. Checks `config/database.yml` for `adapter: postgresql`
2. Tries `psql --version` for local databases (skips for remote hosts)
3. Falls back to `pg` gem version from `Gemfile.lock`

**Note**: For remote databases (AWS RDS, etc.), shows gem version since shell command would give local client version, not server version.

### MySQL Detection

1. Checks `config/database.yml` for `adapter: mysql2` or `adapter: trilogy`
2. Tries `mysql --version` or `mysqld --version` for local databases
3. Falls back to `mysql2` or `trilogy` gem version from `Gemfile.lock`

**Supported adapters**: `mysql2` (traditional) and `trilogy` (Rails 7.1+)

### Redis Detection

1. Checks `docker-compose.yml` for redis image with version tag
2. Tries `redis-server --version` for local installations
3. Falls back to `redis` gem version from `Gemfile.lock`

### MongoDB Detection

1. Checks `docker-compose.yml` for mongo image with version tag
2. Tries `mongod --version` for local installations
3. Falls back to `mongoid` or `mongo` gem version from `Gemfile.lock`

### Python Detection

1. `.python-version` file (highest priority)
2. `pyproject.toml` (`requires-python` field)
3. Docker Compose `python:*` images
4. `python --version` for system installation

### Node.js Detection

1. `.nvmrc` or `.node-version` files (highest priority - explicit version specification)
2. `package.json` `engines.node` field (e.g., ">=18.0.0")
3. Docker Compose `node:*` images
4. `node --version` for system installation

**Version Normalization**: Handles constraint operators (`>=`, `^`, `~`), LTS names (`lts/hydrogen`), and version ranges

### Rust Detection

1. `rust-toolchain` or `rust-toolchain.toml` files (highest priority - explicit toolchain specification)
2. `Cargo.toml` `rust-version` field (MSRV - Minimum Supported Rust Version)
3. Docker Compose `rust:*` images
4. `rustc --version` for system installation (only when Rust project files exist)

**Note:** Symbolic channels like "stable", "beta", "nightly" are skipped as they don't provide specific versions.

### Go Detection

1. `go.mod` file (highest priority - standard Go module version specification)
2. `go.work` file (Go workspace format)
3. `.go-version` file
4. Docker Compose `golang:*` images
5. `go version` for system installation (only when Go project files exist)

**Note:** Shell fallback only executes when Go project files are detected, preventing unnecessary command execution.

## Requirements

- Ruby >= 3.1.0
- Internet connection (for initial EOL data fetch)

## Development

```bash
# Clone the repo
git clone https://github.com/RichD/harbinger.git
cd harbinger

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run locally
bundle exec exe/harbinger scan .
```

## Roadmap

### V1.0 - Current (Ready for Release!)
- ✅ Ruby, Rails, Python, Node.js, Rust, Go version detection
- ✅ PostgreSQL, MySQL, Redis, MongoDB version detection
- ✅ Ecosystem-grouped dashboard with smart component display
- ✅ Export reports to JSON/CSV
- ✅ Bulk scanning with `--recursive` and `rescan` commands
- ✅ 24-hour smart caching for offline support
- ✅ Color-coded EOL warnings

### V1.1 - Next
- 🔷 TypeScript version detection
- 🎯 Framework detection (Django, Flask, Express, Gin)
- 📦 Package manager detection (npm, yarn, pip, bundler, go modules versions)
- 🔍 Dependency vulnerability scanning integration

### V2.0 - Vision
- 🤖 AI-powered upgrade summaries and breaking change analysis
- 📧 Email/Slack notifications for approaching EOL dates
- ☁️ Cloud platform detection (AWS, Heroku, Render)
- 👥 Team collaboration features (shared dashboards)
- 📈 Historical tracking and trends

## Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This gem is available as open source under the terms of the MIT License.

## Credits

- EOL data provided by [endoflife.date](https://endoflife.date)
- Built with ❤️ using Ruby and Thor

## Links

- Website: [stackharbinger.com](https://stackharbinger.com)
- GitHub: [github.com/RichD/harbinger](https://github.com/RichD/harbinger)
- RubyGems: [rubygems.org/gems/stackharbinger](https://rubygems.org/gems/stackharbinger)

---

**Like Harbinger?** Give it a ⭐ on GitHub!
