# Harbinger

**Track End-of-Life dates for your tech stack and stay ahead of deprecations.**

Harbinger is a CLI tool that scans your Ruby and Rails projects, detects versions, and warns you about upcoming EOL (End-of-Life) dates. Never get caught off-guard by unsupported dependencies again.

## Features

- 🔍 **Auto-detects versions** from `.ruby-version`, `Gemfile`, and `Gemfile.lock`
- 📅 **Fetches EOL data** from [endoflife.date](https://endoflife.date)
- 🎨 **Color-coded warnings** (red: already EOL, yellow: <6 months, green: safe)
- ⚡ **Smart caching** (24-hour cache, works offline after first fetch)
- 🚀 **Zero configuration** - just run `harbinger scan`

## Installation

```bash
gem install stackharbinger
```

Or add to your Gemfile:

```ruby
gem 'stackharbinger'
```

The command is still `harbinger` (shorter to type).

## Usage

### Scan a project

```bash
# Scan current directory
harbinger scan

# Scan specific project
harbinger scan ~/Projects/my-rails-app
```

**Example output:**

```
Scanning /Users/you/Projects/my-app...

Detected versions:
  Ruby:  3.2.0
  Rails: 7.0.8

Fetching EOL data...

Ruby 3.2.0:
  EOL Date: 2026-03-31
  Status:   437 days remaining

Rails 7.0.8:
  EOL Date: 2025-06-01
  Status:   ALREADY EOL (474 days ago)
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

### V0.1.0 (Beta) - Current
- ✅ Ruby and Rails version detection
- ✅ EOL data fetching and caching
- ✅ CLI with scan and update commands
- ✅ Color-coded status display

### V0.2.0 - Planned
- 📊 Dashboard: `harbinger show` to see all tracked projects
- 💾 Config management: Save and track multiple projects
- 🐘 PostgreSQL version detection
- 🗄️ MySQL version detection

### V1.0 - Future
- 🐍 Python support (pyproject.toml, requirements.txt)
- 📦 Node.js support (package.json, .nvmrc)
- 🦀 Rust support (Cargo.toml)
- 🏠 Homebrew distribution: `brew install harbinger`

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
