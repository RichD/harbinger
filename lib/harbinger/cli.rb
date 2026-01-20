# frozen_string_literal: true

require "thor"
require "date"
require "tty-table"
require_relative "version"
require "harbinger/analyzers/ruby_detector"
require "harbinger/analyzers/rails_analyzer"
require "harbinger/analyzers/database_detector"
require "harbinger/analyzers/postgres_detector"
require "harbinger/analyzers/mysql_detector"
require "harbinger/analyzers/redis_detector"
require "harbinger/analyzers/mongo_detector"
require "harbinger/analyzers/python_detector"
require "harbinger/analyzers/node_detector"
require "harbinger/analyzers/rust_detector"
require "harbinger/eol_fetcher"
require "harbinger/config_manager"
require "harbinger/exporters/json_exporter"
require "harbinger/exporters/csv_exporter"

module Harbinger
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Ecosystem priority for determining primary language
    ECOSYSTEM_PRIORITY = %w[ruby python rust go nodejs].freeze

    # Ecosystem definitions with languages and databases
    ECOSYSTEMS = {
      "ruby" => {
        name: "Ruby Ecosystem",
        languages: ["ruby", "rails"],
        databases: ["postgres", "mysql", "redis", "mongo"]
      },
      "python" => {
        name: "Python Ecosystem",
        languages: ["python"],
        databases: ["postgres", "mysql", "redis", "mongo"]
      },
      "rust" => {
        name: "Rust Ecosystem",
        languages: ["rust"],
        databases: ["postgres", "mysql", "redis", "mongo"]
      },
      "go" => {
        name: "Go Ecosystem",
        languages: ["go"],
        databases: ["postgres", "mysql", "redis", "mongo"]
      },
      "nodejs" => {
        name: "Node.js Ecosystem",
        languages: ["nodejs"],
        databases: ["postgres", "mysql", "redis", "mongo"]
      }
    }.freeze

    # Component display names for table headers
    COMPONENT_DISPLAY_NAMES = {
      "ruby" => "Ruby",
      "rails" => "Rails",
      "python" => "Python",
      "nodejs" => "Node.js",
      "rust" => "Rust",
      "go" => "Go",
      "postgres" => "PostgreSQL",
      "mysql" => "MySQL",
      "redis" => "Redis",
      "mongo" => "MongoDB"
    }.freeze

    # Product name mapping for EOL API lookups
    PRODUCT_NAME_MAP = {
      "ruby" => "ruby",
      "rails" => "rails",
      "postgres" => "postgresql",
      "mysql" => "mysql",
      "redis" => "redis",
      "mongo" => "mongodb",
      "python" => "python",
      "nodejs" => "nodejs",
      "rust" => "rust"
    }.freeze

    desc "scan", "Scan a project directory and detect versions"
    option :path, type: :string, aliases: "-p", desc: "Path to project directory (defaults to current directory)"
    option :save, type: :boolean, aliases: "-s", desc: "Save project to config for dashboard"
    option :recursive, type: :boolean, aliases: "-r", desc: "Recursively scan all subdirectories with Gemfiles"
    def scan
      project_path = File.expand_path(options[:path] || Dir.pwd)

      unless File.directory?(project_path)
        say "Error: #{project_path} is not a valid directory", :red
        exit 1
      end

      if options[:recursive]
        scan_recursive(project_path)
      else
        scan_single(project_path)
      end
    end

    desc "show [PROJECT]", "Show EOL status for tracked projects"
    option :verbose, type: :boolean, aliases: "-v", desc: "Show project paths"
    option :format, type: :string, enum: %w[table json csv], default: "table", desc: "Output format (table, json, csv)"
    option :output, type: :string, aliases: "-o", desc: "Output file path"
    def show(project_filter = nil)
      config_manager = ConfigManager.new
      projects = config_manager.list_projects

      if projects.empty?
        say "No projects tracked yet.", :yellow
        say "Use 'harbinger scan --save' to add projects", :cyan
        return
      end

      # Filter by project name or path if specified
      if project_filter
        projects = projects.select do |name, data|
          name.downcase.include?(project_filter.downcase) ||
            data["path"]&.downcase&.include?(project_filter.downcase)
        end

        if projects.empty?
          say "No projects matching '#{project_filter}'", :yellow
          return
        end
      end

      # Handle export formats
      if options[:format] != "table"
        export_data(projects, options[:format], options[:output])
        return
      end

      # Group projects by ecosystem
      fetcher = EolFetcher.new
      ecosystem_projects = group_projects_by_ecosystem(projects)

      # Check if any projects have a programming language
      if ecosystem_projects.empty?
        say "No projects with detected versions.", :yellow
        say "Use 'harbinger scan --save' to add projects", :cyan
        return
      end

      # Display header with total project count
      total_projects = ecosystem_projects.values.sum(&:size)
      say "Tracked Projects (#{total_projects})", :cyan

      # Render each ecosystem table
      ECOSYSTEMS.keys.each do |ecosystem_key|
        projects_in_ecosystem = ecosystem_projects[ecosystem_key]
        next if projects_in_ecosystem.empty? # Hide empty tables

        render_ecosystem_table(
          ecosystem_key,
          projects_in_ecosystem,
          fetcher,
          verbose: options[:verbose]
        )
      end

      say "\nUse 'harbinger scan --path <project>' to update a project", :cyan
    end

    desc "update", "Force refresh EOL data from endoflife.date"
    def update
      say "Updating EOL data...", :cyan

      fetcher = EolFetcher.new
      products = %w[ruby rails postgresql mysql redis mongodb python nodejs rust]

      products.each do |product|
        say "Fetching #{product}...", :white
        data = fetcher.fetch(product)

        if data
          say "  ✓ #{product.capitalize}: #{data.length} versions cached", :green
        else
          say "  ✗ #{product.capitalize}: Failed to fetch", :red
        end
      end

      say "\nEOL data updated successfully!", :green
    end

    desc "remove PROJECT", "Remove a project from tracking"
    def remove(project_name)
      config_manager = ConfigManager.new
      project = config_manager.get_project(project_name)

      if project
        config_manager.remove_project(project_name)
        say "Removed '#{project_name}' (#{project["path"]})", :green
      else
        say "Project '#{project_name}' not found", :yellow
        say "\nTracked projects:", :cyan
        config_manager.list_projects.keys.sort.each { |name| say "  #{name}" }
      end
    end

    desc "rescan", "Re-scan all tracked projects and update versions"
    option :verbose, type: :boolean, aliases: "-v", desc: "Show detailed output for each project"
    def rescan
      config_manager = ConfigManager.new
      projects = config_manager.list_projects

      if projects.empty?
        say "No projects tracked yet.", :yellow
        say "Use 'harbinger scan --save' to add projects", :cyan
        return
      end

      say "Re-scanning #{projects.size} tracked project(s)...\n\n", :cyan

      updated_count = 0
      removed_count = 0

      projects.each_with_index do |(name, data), index|
        project_path = data["path"]

        unless File.directory?(project_path)
          say "[#{index + 1}/#{projects.size}] #{name}: Path not found, removing from config", :yellow
          config_manager.remove_project(name)
          removed_count += 1
          next
        end

        if options[:verbose]
          say "=" * 60, :cyan
          say "[#{index + 1}/#{projects.size}] Re-scanning #{name}", :cyan
          say "=" * 60, :cyan
          scan_single(project_path)
        else
          say "[#{index + 1}/#{projects.size}] #{name}...", :white

          # Detect versions quietly
          ruby_detector = Analyzers::RubyDetector.new(project_path)
          rails_analyzer = Analyzers::RailsAnalyzer.new(project_path)
          postgres_detector = Analyzers::PostgresDetector.new(project_path)
          mysql_detector = Analyzers::MysqlDetector.new(project_path)
          redis_detector = Analyzers::RedisDetector.new(project_path)
          mongo_detector = Analyzers::MongoDetector.new(project_path)
          python_detector = Analyzers::PythonDetector.new(project_path)
          node_detector = Analyzers::NodeDetector.new(project_path)
          rust_detector = Analyzers::RustDetector.new(project_path)

          ruby_version = ruby_detector.detect
          rails_version = rails_analyzer.detect
          postgres_version = postgres_detector.detect
          mysql_version = mysql_detector.detect
          redis_version = redis_detector.detect
          mongo_version = mongo_detector.detect
          python_version = python_detector.detect
          nodejs_version = node_detector.detect
          rust_version = rust_detector.detect

          # Save to config
          config_manager.save_project(
            name: name,
            path: project_path,
            versions: {
              ruby: ruby_version,
              rails: rails_version,
              postgres: postgres_version,
              mysql: mysql_version,
              redis: redis_version,
              mongo: mongo_version,
              python: python_version,
              nodejs: nodejs_version,
              rust: rust_version
            }.compact
          )
        end

        updated_count += 1
      end

      say "\n✓ Updated #{updated_count} project(s)", :green
      say "✓ Removed #{removed_count} project(s) with missing directories", :yellow if removed_count.positive?
      say "\nView updated projects with: harbinger show", :cyan
    end

    desc "version", "Show harbinger version"
    def version
      say "Harbinger version #{Harbinger::VERSION}", :cyan
    end

    private

    # Calculate EOL status for a single component (e.g., ruby, rails, postgres)
    # Returns: { status: :red/:yellow/:green, text: "✗ Ruby EOL", days: -30 } or nil
    def calculate_component_status(component, version, fetcher)
      return nil unless version && !version.empty?

      product_name = PRODUCT_NAME_MAP[component]
      eol_date = fetcher.eol_date_for(product_name, version)
      return nil unless eol_date

      days = days_until(eol_date)
      status = eol_color(days)

      component_display = COMPONENT_DISPLAY_NAMES[component] || component.capitalize

      text = if days.negative?
               "✗ #{component_display} EOL"
             elsif days < 180
               "⚠ #{component_display} ending soon"
             else
               "✓ Current"
             end

      { status: status, text: text, days: days }
    end

    # Determine overall status for a project across specified components
    # Returns: { status: :red/:yellow/:green, text: "✗ Ruby EOL" }
    def determine_overall_status(project_data, components, fetcher)
      worst_status = :green
      status_text = "✓ Current"

      components.each do |component|
        version = project_data[component]
        next unless version && !version.empty?

        # Filter out gem-only database versions
        if %w[postgres mysql redis mongo].include?(component) && version&.include?("gem")
          next
        end

        component_status = calculate_component_status(component, version, fetcher)
        next unless component_status

        if status_priority(component_status[:status]) > status_priority(worst_status)
          worst_status = component_status[:status]
          status_text = component_status[:text]
        end
      end

      { status: worst_status, text: status_text }
    end

    # Build a row hash for a single project with all its component versions
    # Returns: { name: "project", path: "/path", ruby: "3.2.0", ..., status: colored_text }
    def build_project_row(name, data, components, fetcher, verbose: false)
      row = { name: name }
      row[:path] = File.dirname(data["path"] || "") if verbose

      # Add component versions
      components.each do |component|
        version = data[component]
        # Filter out gem-only database versions
        if %w[postgres mysql redis mongo].include?(component) && version&.include?("gem")
          version = nil
        end
        row[component.to_sym] = (version && !version.empty?) ? version : "-"
      end

      # Calculate overall status
      status_info = determine_overall_status(data, components, fetcher)
      row[:status] = colorize_status(status_info[:text], status_info[:status])
      row[:status_raw] = status_info[:text]

      row
    end

    # Determine the primary ecosystem for a project based on detected languages
    # Returns: "ruby", "python", "rust", "go", "nodejs", or nil
    def determine_primary_ecosystem(data)
      ECOSYSTEM_PRIORITY.each do |lang|
        version = data[lang]
        return lang if version && !version.empty?
      end
      nil # No language detected
    end

    # Group projects by their primary ecosystem
    # Returns: { "ruby" => [[name, data], ...], "python" => [[name, data], ...] }
    def group_projects_by_ecosystem(projects)
      ecosystem_projects = Hash.new { |h, k| h[k] = [] }

      projects.each do |name, data|
        primary = determine_primary_ecosystem(data)

        # Skip projects with no programming language detected
        next unless primary

        ecosystem_projects[primary] << [name, data]
      end

      ecosystem_projects
    end

    # Render a table for a single ecosystem with its projects
    def render_ecosystem_table(ecosystem_key, projects, fetcher, verbose: false)
      config = ECOSYSTEMS[ecosystem_key]
      components = config[:languages] + config[:databases]

      # Track which columns have data in this ecosystem
      has_columns = Hash.new(false)
      rows = []

      projects.each do |name, data|
        row = build_project_row(name, data, components, fetcher, verbose: verbose)

        # Track columns with data
        components.each do |component|
          has_columns[component] = true if row[component.to_sym] != "-"
        end

        rows << row
      end

      return if rows.empty? # Skip empty ecosystems

      # Sort by status priority (worst first)
      rows.sort_by! do |row|
        priority = if row[:status_raw].include?("✗")
                     0
                   elsif row[:status_raw].include?("⚠")
                     1
                   else
                     2
                   end
        [priority, row[:name]]
      end

      # Build dynamic headers
      headers = ["Project"]
      headers << "Path" if verbose

      components.each do |component|
        next unless has_columns[component]

        headers << COMPONENT_DISPLAY_NAMES[component]
      end

      headers << "Status"

      # Build table rows matching headers
      table_rows = rows.map do |row|
        table_row = [row[:name]]
        table_row << row[:path] if verbose

        components.each do |component|
          next unless has_columns[component]

          table_row << row[component.to_sym]
        end

        table_row << row[:status]
        table_row
      end

      # Render the table
      say "\n#{config[:name]} (#{rows.size})", :cyan
      say "=" * 80, :cyan

      table = TTY::Table.new(header: headers, rows: table_rows)
      puts table.render(:unicode, padding: [0, 1], resize: false)
    end

    def scan_recursive(base_path)
      say "Scanning #{base_path} recursively for Ruby projects...", :cyan

      # Find all directories with Gemfiles, excluding common non-project directories
      excluded_patterns = %w[
        vendor/
        node_modules/
        tmp/
        .git/
        spec/fixtures/
        test/fixtures/
      ]

      gemfile_dirs = Dir.glob(File.join(base_path, "**/Gemfile"))
                        .map { |f| File.dirname(f) }
                        .reject { |dir| excluded_patterns.any? { |pattern| dir.include?("/#{pattern}") } }
                        .sort

      if gemfile_dirs.empty?
        say "\nNo Ruby projects found (no Gemfile detected)", :yellow
        return
      end

      say "Found #{gemfile_dirs.length} project(s)\n\n", :green

      gemfile_dirs.each_with_index do |project_path, index|
        say "=" * 60, :cyan
        say "[#{index + 1}/#{gemfile_dirs.length}] #{project_path}", :cyan
        say "=" * 60, :cyan
        scan_single(project_path)
        say "\n" unless index == gemfile_dirs.length - 1
      end

      return unless options[:save]

      say "\n✓ Saved #{gemfile_dirs.length} project(s) to config", :green
      say "View all tracked projects with: harbinger show", :cyan
    end

    def scan_single(project_path)
      say "Scanning #{project_path}...", :cyan unless options[:recursive]

      # Detect versions
      ruby_detector = Analyzers::RubyDetector.new(project_path)
      rails_analyzer = Analyzers::RailsAnalyzer.new(project_path)
      postgres_detector = Analyzers::PostgresDetector.new(project_path)
      mysql_detector = Analyzers::MysqlDetector.new(project_path)
      redis_detector = Analyzers::RedisDetector.new(project_path)
      mongo_detector = Analyzers::MongoDetector.new(project_path)
      python_detector = Analyzers::PythonDetector.new(project_path)
      node_detector = Analyzers::NodeDetector.new(project_path)
      rust_detector = Analyzers::RustDetector.new(project_path)

      ruby_version = ruby_detector.detect
      rails_version = rails_analyzer.detect
      postgres_version = postgres_detector.detect
      mysql_version = mysql_detector.detect
      redis_version = redis_detector.detect
      mongo_version = mongo_detector.detect
      python_version = python_detector.detect
      nodejs_version = node_detector.detect
      rust_version = rust_detector.detect

      # Prepare data for ecosystem detection
      data = {
        "ruby" => ruby_version,
        "rails" => rails_version,
        "postgres" => postgres_version,
        "mysql" => mysql_version,
        "redis" => redis_version,
        "mongo" => mongo_version,
        "python" => python_version,
        "nodejs" => nodejs_version,
        "rust" => rust_version
      }

      # Determine primary ecosystem
      primary_ecosystem = determine_primary_ecosystem(data)

      if primary_ecosystem.nil?
        say "\nNo programming language detected", :yellow
        say "This appears to be a database-only or infrastructure project", :yellow
        return
      end

      # Get components to display for this ecosystem
      config = ECOSYSTEMS[primary_ecosystem]
      components_to_display = config[:languages] + config[:databases]

      # Display results
      say "\nDetected versions:", :green

      components_to_display.each do |component|
        version = data[component]
        display_name = COMPONENT_DISPLAY_NAMES[component]
        detector_present = case component
                           when "ruby" then ruby_detector.ruby_detected?
                           when "rails" then rails_analyzer.rails_detected?
                           when "postgres" then postgres_detector.database_detected?
                           when "mysql" then mysql_detector.database_detected?
                           when "redis" then redis_detector.redis_detected?
                           when "mongo" then mongo_detector.mongo_detected?
                           when "python" then python_detector.python_detected?
                           when "nodejs" then node_detector.nodejs_detected?
                           when "rust" then rust_detector.rust_detected?
                           else false
                           end

        if version && !version.empty?
          say "  #{display_name.ljust(12)} #{version}", :white
        elsif detector_present
          say "  #{display_name.ljust(12)} Present (version not detected)", :yellow
        end
      end

      # Fetch and display EOL dates
      versions_to_check = components_to_display.filter_map do |component|
        version = data[component]
        next unless version && !version.empty?
        # Filter out gem-only database versions
        next if %w[postgres mysql redis mongo].include?(component) && version.include?("gem")

        [component, version]
      end

      if versions_to_check.any?
        say "\nFetching EOL data...", :cyan
        fetcher = EolFetcher.new

        versions_to_check.each do |component, version|
          display_name = COMPONENT_DISPLAY_NAMES[component]
          display_eol_info(fetcher, display_name, version)
        end
      end

      # Save to config if --save flag is used
      versions = {
        ruby: ruby_version,
        rails: rails_version,
        postgres: postgres_version,
        mysql: mysql_version,
        redis: redis_version,
        mongo: mongo_version,
        python: python_version,
        nodejs: nodejs_version,
        rust: rust_version
      }.compact

      if options[:save] && !options[:recursive]
        save_project_to_config(project_path, versions)
      elsif options[:save] && options[:recursive]
        # In recursive mode, save without the confirmation message for each project
        config_manager = ConfigManager.new
        project_name = File.basename(project_path)
        config_manager.save_project(
          name: project_name,
          path: project_path,
          versions: versions
        )
      end
    end

    def save_project_to_config(project_path, versions)
      config_manager = ConfigManager.new
      project_name = File.basename(project_path)

      config_manager.save_project(
        name: project_name,
        path: project_path,
        versions: versions
      )

      say "\n✓ Saved to config as '#{project_name}'", :green
      say "View all tracked projects with: harbinger show", :cyan
    end

    def display_eol_info(fetcher, product, version)
      # Map display name to EOL API key
      product_key = case product.downcase
                    when "node.js" then "nodejs"
                    when "postgresql" then "postgresql"
                    when "mongodb" then "mongodb"
                    else product.downcase
                    end

      eol_date = fetcher.eol_date_for(product_key, version)

      if eol_date
        days_until_eol = days_until(eol_date)
        color = eol_color(days_until_eol)

        say "\n#{product} #{version}:", :white
        say "  EOL Date: #{eol_date}", color
        say "  Status:   #{eol_status(days_until_eol)}", color
      else
        say "\n#{product} #{version}:", :white
        say "  EOL Date: Unknown (version not found in database)", :yellow
      end
    end

    def days_until(date_string)
      eol_date = Date.parse(date_string)
      (eol_date - Date.today).to_i
    end

    def eol_color(days)
      if days.negative?
        :red
      elsif days < 180 # < 6 months
        :yellow
      else
        :green
      end
    end

    def eol_status(days)
      if days.negative?
        "ALREADY EOL (#{days.abs} days ago)"
      elsif days < 30
        "ENDING SOON (#{days} days remaining)"
      elsif days < 180
        "#{days} days remaining"
      else
        "#{days} days remaining"
      end
    end

    def status_priority(color)
      case color
      when :red
        2
      when :yellow
        1
      else
        0
      end
    end

    def colorize_status(text, color)
      case color
      when :red
        "\e[31m#{text}\e[0m"
      when :yellow
        "\e[33m#{text}\e[0m"
      when :green
        "\e[32m#{text}\e[0m"
      else
        text
      end
    end

    def export_data(projects, format, output_path)
      exporter = case format
                 when "json"
                   Exporters::JsonExporter.new(projects)
                 when "csv"
                   Exporters::CsvExporter.new(projects)
                 end

      result = exporter.export

      if output_path
        File.write(output_path, result)
        say "Exported to #{output_path}", :green
      else
        puts result
      end
    end
  end
end
