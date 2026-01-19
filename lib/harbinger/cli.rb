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
require "harbinger/eol_fetcher"
require "harbinger/config_manager"
require "harbinger/exporters/json_exporter"
require "harbinger/exporters/csv_exporter"

module Harbinger
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

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

      fetcher = EolFetcher.new
      rows = []

      # Track which columns have data
      has_ruby = false
      has_rails = false
      has_postgres = false
      has_mysql = false
      has_redis = false
      has_mongo = false

      projects.each do |name, data|
        ruby_version = data["ruby"]
        rails_version = data["rails"]
        postgres_version = data["postgres"]
        mysql_version = data["mysql"]
        redis_version = data["redis"]
        mongo_version = data["mongo"]

        # Filter out gem-only database versions
        postgres_version = nil if postgres_version&.include?("gem")
        mysql_version = nil if mysql_version&.include?("gem")
        redis_version = nil if redis_version&.include?("gem")
        mongo_version = nil if mongo_version&.include?("gem")

        # Skip projects with no matching products
        ruby_present = ruby_version && !ruby_version.empty?
        rails_present = rails_version && !rails_version.empty?
        postgres_present = postgres_version && !postgres_version.empty?
        mysql_present = mysql_version && !mysql_version.empty?
        redis_present = redis_version && !redis_version.empty?
        mongo_present = mongo_version && !mongo_version.empty?

        next unless ruby_present || rails_present || postgres_present || mysql_present || redis_present || mongo_present

        # Track which columns have data
        has_ruby ||= ruby_present
        has_rails ||= rails_present
        has_postgres ||= postgres_present
        has_mysql ||= mysql_present
        has_redis ||= redis_present
        has_mongo ||= mongo_present

        # Determine worst EOL status
        worst_status = :green
        status_text = "✓ Current"

        if ruby_present
          ruby_eol = fetcher.eol_date_for("ruby", ruby_version)
          if ruby_eol
            days = days_until(ruby_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ Ruby EOL"
            elsif days < 180
              status_text = "⚠ Ruby ending soon"
            end
          end
        end

        if rails_present
          rails_eol = fetcher.eol_date_for("rails", rails_version)
          if rails_eol
            days = days_until(rails_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ Rails EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ Rails ending soon"
            end
          end
        end

        if postgres_present
          postgres_eol = fetcher.eol_date_for("postgresql", postgres_version)
          if postgres_eol
            days = days_until(postgres_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ PostgreSQL EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ PostgreSQL ending soon"
            end
          end
        end

        if mysql_present
          mysql_eol = fetcher.eol_date_for("mysql", mysql_version)
          if mysql_eol
            days = days_until(mysql_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ MySQL EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ MySQL ending soon"
            end
          end
        end

        if redis_present
          redis_eol = fetcher.eol_date_for("redis", redis_version)
          if redis_eol
            days = days_until(redis_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ Redis EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ Redis ending soon"
            end
          end
        end

        if mongo_present
          mongo_eol = fetcher.eol_date_for("mongodb", mongo_version)
          if mongo_eol
            days = days_until(mongo_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days.negative?
              status_text = "✗ MongoDB EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ MongoDB ending soon"
            end
          end
        end

        rows << {
          name: name,
          path: File.dirname(data["path"] || ""),
          ruby: ruby_present ? ruby_version : "-",
          rails: rails_present ? rails_version : "-",
          postgres: postgres_present ? postgres_version : "-",
          mysql: mysql_present ? mysql_version : "-",
          redis: redis_present ? redis_version : "-",
          mongo: mongo_present ? mongo_version : "-",
          status: colorize_status(status_text, worst_status),
          status_raw: status_text
        }
      end

      if rows.empty?
        say "No projects with detected versions.", :yellow
        say "Use 'harbinger scan --save' to add projects", :cyan
        return
      end

      say "Tracked Projects (#{rows.size})", :cyan
      say "=" * 80, :cyan

      # Sort by status priority (worst first), then by name
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

      # Build dynamic headers and rows
      headers = ["Project"]
      headers << "Path" if options[:verbose]
      headers << "Ruby" if has_ruby
      headers << "Rails" if has_rails
      headers << "PostgreSQL" if has_postgres
      headers << "MySQL" if has_mysql
      headers << "Redis" if has_redis
      headers << "MongoDB" if has_mongo
      headers << "Status"

      table_rows = rows.map do |row|
        table_row = [row[:name]]
        table_row << row[:path] if options[:verbose]
        table_row << row[:ruby] if has_ruby
        table_row << row[:rails] if has_rails
        table_row << row[:postgres] if has_postgres
        table_row << row[:mysql] if has_mysql
        table_row << row[:redis] if has_redis
        table_row << row[:mongo] if has_mongo
        table_row << row[:status]
        table_row
      end

      table = TTY::Table.new(
        header: headers,
        rows: table_rows
      )

      puts table.render(:unicode, padding: [0, 1], resize: false)

      say "\nUse 'harbinger scan --path <project>' to update a project", :cyan
    end

    desc "update", "Force refresh EOL data from endoflife.date"
    def update
      say "Updating EOL data...", :cyan

      fetcher = EolFetcher.new
      products = %w[ruby rails postgresql mysql redis mongodb]

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

          ruby_version = ruby_detector.detect
          rails_version = rails_analyzer.detect
          postgres_version = postgres_detector.detect
          mysql_version = mysql_detector.detect
          redis_version = redis_detector.detect
          mongo_version = mongo_detector.detect

          # Save to config
          config_manager.save_project(
            name: name,
            path: project_path,
            versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version,
                        mysql: mysql_version, redis: redis_version, mongo: mongo_version }.compact
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

      ruby_version = ruby_detector.detect
      rails_version = rails_analyzer.detect
      postgres_version = postgres_detector.detect
      mysql_version = mysql_detector.detect
      redis_version = redis_detector.detect
      mongo_version = mongo_detector.detect

      ruby_present = ruby_detector.ruby_detected?
      rails_present = rails_analyzer.rails_detected?
      postgres_present = postgres_detector.database_detected?
      mysql_present = mysql_detector.database_detected?
      redis_present = redis_detector.redis_detected?
      mongo_present = mongo_detector.mongo_detected?

      # Display results
      say "\nDetected versions:", :green
      if ruby_version
        say "  Ruby:       #{ruby_version}", :white
      elsif ruby_present
        say "  Ruby:       Present (version not specified - add .ruby-version or ruby declaration in Gemfile)", :yellow
      else
        say "  Ruby:       Not a Ruby project", :red
      end

      if rails_version
        say "  Rails:      #{rails_version}", :white
      elsif rails_present
        say "  Rails:      Present (version not found in Gemfile.lock)", :yellow
      else
        say "  Rails:      Not detected", :yellow
      end

      if postgres_version
        say "  PostgreSQL: #{postgres_version}", :white
      elsif postgres_present
        say "  PostgreSQL: Present (version not detected)", :yellow
      end

      if mysql_version
        say "  MySQL:      #{mysql_version}", :white
      elsif mysql_present
        say "  MySQL:      Present (version not detected)", :yellow
      end

      if redis_version
        say "  Redis:      #{redis_version}", :white
      elsif redis_present
        say "  Redis:      Present (version not detected)", :yellow
      end

      if mongo_version
        say "  MongoDB:    #{mongo_version}", :white
      elsif mongo_present
        say "  MongoDB:    Present (version not detected)", :yellow
      end

      # Fetch and display EOL dates
      if ruby_version || rails_version || postgres_version || mysql_version || redis_version || mongo_version
        say "\nFetching EOL data...", :cyan
        fetcher = EolFetcher.new

        display_eol_info(fetcher, "Ruby", ruby_version) if ruby_version

        display_eol_info(fetcher, "Rails", rails_version) if rails_version

        if postgres_version && !postgres_version.include?("gem")
          display_eol_info(fetcher, "PostgreSQL", postgres_version)
        end

        display_eol_info(fetcher, "MySQL", mysql_version) if mysql_version && !mysql_version.include?("gem")

        display_eol_info(fetcher, "Redis", redis_version) if redis_version && !redis_version.include?("gem")

        display_eol_info(fetcher, "MongoDB", mongo_version) if mongo_version && !mongo_version.include?("gem")
      end

      # Save to config if --save flag is used
      if options[:save] && !options[:recursive]
        save_project_to_config(project_path, ruby_version, rails_version, postgres_version, mysql_version,
                               redis_version, mongo_version)
      elsif options[:save] && options[:recursive]
        # In recursive mode, save without the confirmation message for each project
        config_manager = ConfigManager.new
        project_name = File.basename(project_path)
        config_manager.save_project(
          name: project_name,
          path: project_path,
          versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version,
                      mysql: mysql_version, redis: redis_version, mongo: mongo_version }.compact
        )
      end
    end

    def save_project_to_config(project_path, ruby_version, rails_version, postgres_version, mysql_version,
                               redis_version, mongo_version)
      config_manager = ConfigManager.new
      project_name = File.basename(project_path)

      config_manager.save_project(
        name: project_name,
        path: project_path,
        versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version,
                    mysql: mysql_version, redis: redis_version, mongo: mongo_version }.compact
      )

      say "\n✓ Saved to config as '#{project_name}'", :green
      say "View all tracked projects with: harbinger show", :cyan
    end

    def display_eol_info(fetcher, product, version)
      product_key = product.downcase
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
