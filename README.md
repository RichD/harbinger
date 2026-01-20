# Harbinger

**Track End-of-Life dates for your tech stack and stay ahead of deprecations.**

Harbinger is a CLI tool that scans your Ruby, Rails, PostgreSQL, MySQL, Redis, MongoDB, Python, and Node.js versions, and warns you about upcoming EOL (End-of-Life) dates. Never get caught off-guard by unsupported dependencies again.

## Features

- 🔍 **Auto-detects versions** from `.ruby-version`, `Gemfile`, `Gemfile.lock`, `.nvmrc`, `.python-version`, `pyproject.toml`, `package.json`, `config/database.yml`, and `docker-compose.yml`
- 🐘 **Database detection** for PostgreSQL and MySQL (mysql2/trilogy adapters)
- 📅 **Fetches EOL data** from [endoflife.date](https://endoflife.date)
- 🎨 **Color-coded warnings** (red: already EOL, yellow: <6 months, green: safe)
- ⚡ **Smart caching** (24-hour cache, works offline after first fetch)
- 📊 **Track multiple projects** with `--save` and view dashboard with `harbinger show`
- 🔄 **Bulk operations** with `--recursive` scan and `rescan` command
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
Tracked Projects (10)
================================================================================
┌───────────────────┬───────┬──────────┬────────────┬───────┬─────────────┐
│ Project           │ Ruby  │ Rails    │ PostgreSQL │ MySQL │ Status      │
├───────────────────┼───────┼──────────┼────────────┼───────┼─────────────┤
│ ledger            │ 3.3.0 │ 6.1.7.10 │ -          │ -     │ ✗ Rails EOL │
│ option_tracker    │ 3.3.0 │ 7.0.8.7  │ -          │ -     │ ✗ Rails EOL │
│ CarCal            │ -     │ 8.0.2    │ -          │ -     │ ✓ Current   │
│ job_tracker       │ 3.3.0 │ 8.0.4    │ 16.11      │ -     │ ✓ Current   │
└───────────────────┴───────┴──────────┴────────────┴───────┴─────────────┘
```

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
   - PostgreSQL: `config/database.yml` (adapter check) + `psql --version` or `pg` gem
   - MySQL: `config/database.yml` (mysql2/trilogy adapter) + `mysql --version` or gem version
   - Redis: `docker-compose.yml` + `redis-server --version` or `redis` gem
   - MongoDB: `docker-compose.yml` + `mongod --version` or `mongoid`/`mongo` gem
   - Python: `.python-version`, `pyproject.toml`, `docker-compose.yml`, or `python --version`
   - Node.js: `.nvmrc`, `.node-version`, `package.json` engines, `docker-compose.yml`, or `node --version`

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

### V0.5.0 - Current
- ✅ Python version detection (pyproject.toml, .python-version)
- ✅ Node.js version detection (package.json, .nvmrc, .node-version)

### V0.4.0
- ✅ Export reports to JSON/CSV
- ✅ Docker Compose database version detection
- ✅ Redis version detection
- ✅ MongoDB version detection

### V0.3.0
- ✅ PostgreSQL version detection with local/remote database handling
- ✅ MySQL version detection (mysql2 and trilogy adapters)
- ✅ Rescan command to update all tracked projects
- ✅ Enhanced dashboard with database columns
- ✅ EOL tracking for PostgreSQL and MySQL

### V1.0 - Future
- 🦀 Rust support (Cargo.toml)
- 🐘 Go support (go.mod)
- 🔷 TypeScript version detection
- 📦 Package manager detection (npm, yarn, pip)

### V2.0 - Vision
- 🤖 AI-powered upgrade summaries
- 📧 Email/Slack notifications
- ☁️ Cloud platform detection (AWS, Heroku, etc.)
- 👥 Team collaboration features

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
