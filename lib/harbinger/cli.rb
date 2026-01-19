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
require "harbinger/eol_fetcher"
require "harbinger/config_manager"

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
      project_path = options[:path] || Dir.pwd

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

    desc "show", "Show EOL status for tracked projects"
    def show
      config_manager = ConfigManager.new
      projects = config_manager.list_projects

      if projects.empty?
        say "No projects tracked yet.", :yellow
        say "Use 'harbinger scan --save' to add projects", :cyan
        return
      end

      say "Tracked Projects (#{projects.size})", :cyan
      say "=" * 80, :cyan

      fetcher = EolFetcher.new
      rows = []

      projects.each do |name, data|
        ruby_version = data["ruby"]
        rails_version = data["rails"]
        postgres_version = data["postgres"]
        mysql_version = data["mysql"]

        # Determine worst EOL status
        worst_status = :green
        status_text = "✓ Current"

        if ruby_version && !ruby_version.empty?
          ruby_eol = fetcher.eol_date_for("ruby", ruby_version)
          if ruby_eol
            days = days_until(ruby_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days < 0
              status_text = "✗ Ruby EOL"
            elsif days < 180
              status_text = "⚠ Ruby ending soon"
            end
          end
        end

        if rails_version && !rails_version.empty?
          rails_eol = fetcher.eol_date_for("rails", rails_version)
          if rails_eol
            days = days_until(rails_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days < 0
              status_text = "✗ Rails EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ Rails ending soon"
            end
          end
        end

        if postgres_version && !postgres_version.empty? && !postgres_version.include?("gem")
          postgres_eol = fetcher.eol_date_for("postgresql", postgres_version)
          if postgres_eol
            days = days_until(postgres_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days < 0
              status_text = "✗ PostgreSQL EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ PostgreSQL ending soon"
            end
          end
        end

        if mysql_version && !mysql_version.empty? && !mysql_version.include?("gem")
          mysql_eol = fetcher.eol_date_for("mysql", mysql_version)
          if mysql_eol
            days = days_until(mysql_eol)
            status = eol_color(days)
            worst_status = status if status_priority(status) > status_priority(worst_status)
            if days < 0
              status_text = "✗ MySQL EOL"
            elsif days < 180 && !status_text.include?("EOL")
              status_text = "⚠ MySQL ending soon"
            end
          end
        end

        ruby_display = ruby_version && !ruby_version.empty? ? ruby_version : "-"
        rails_display = rails_version && !rails_version.empty? ? rails_version : "-"
        postgres_display = postgres_version && !postgres_version.empty? ? postgres_version : "-"
        mysql_display = mysql_version && !mysql_version.empty? ? mysql_version : "-"

        rows << [name, ruby_display, rails_display, postgres_display, mysql_display, colorize_status(status_text, worst_status)]
      end

      # Sort by status priority (worst first), then by name
      rows.sort_by! do |row|
        status = row[5] # Status is now in column 5 (0-indexed)
        priority = if status.include?("✗")
          0
        elsif status.include?("⚠")
          1
        else
          2
        end
        [priority, row[0]]
      end

      table = TTY::Table.new(
        header: ["Project", "Ruby", "Rails", "PostgreSQL", "MySQL", "Status"],
        rows: rows
      )

      puts table.render(:unicode, padding: [0, 1])

      say "\nUse 'harbinger scan --path <project>' to update a project", :cyan
    end

    desc "update", "Force refresh EOL data from endoflife.date"
    def update
      say "Updating EOL data...", :cyan

      fetcher = EolFetcher.new
      products = %w[ruby rails postgresql mysql]

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

          ruby_version = ruby_detector.detect
          rails_version = rails_analyzer.detect
          postgres_version = postgres_detector.detect
          mysql_version = mysql_detector.detect

          # Save to config
          config_manager.save_project(
            name: name,
            path: project_path,
            versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version, mysql: mysql_version }.compact
          )
        end

        updated_count += 1
      end

      say "\n✓ Updated #{updated_count} project(s)", :green
      say "✓ Removed #{removed_count} project(s) with missing directories", :yellow if removed_count > 0
      say "\nView updated projects with: harbinger show", :cyan
    end

    desc "version", "Show harbinger version"
    def version
      say "Harbinger version #{Harbinger::VERSION}", :cyan
    end

    private

    def scan_recursive(base_path)
      say "Scanning #{base_path} recursively for Ruby projects...", :cyan

      # Find all directories with Gemfiles
      gemfile_dirs = Dir.glob(File.join(base_path, "**/Gemfile"))
                        .map { |f| File.dirname(f) }
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

      if options[:save]
        say "\n✓ Saved #{gemfile_dirs.length} project(s) to config", :green
        say "View all tracked projects with: harbinger show", :cyan
      end
    end

    def scan_single(project_path)
      say "Scanning #{project_path}...", :cyan unless options[:recursive]

      # Detect versions
      ruby_detector = Analyzers::RubyDetector.new(project_path)
      rails_analyzer = Analyzers::RailsAnalyzer.new(project_path)
      postgres_detector = Analyzers::PostgresDetector.new(project_path)
      mysql_detector = Analyzers::MysqlDetector.new(project_path)

      ruby_version = ruby_detector.detect
      rails_version = rails_analyzer.detect
      postgres_version = postgres_detector.detect
      mysql_version = mysql_detector.detect

      ruby_present = ruby_detector.ruby_detected?
      rails_present = rails_analyzer.rails_detected?
      postgres_present = postgres_detector.database_detected?
      mysql_present = mysql_detector.database_detected?

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

      # Fetch and display EOL dates
      if ruby_version || rails_version || postgres_version || mysql_version
        say "\nFetching EOL data...", :cyan
        fetcher = EolFetcher.new

        if ruby_version
          display_eol_info(fetcher, "Ruby", ruby_version)
        end

        if rails_version
          display_eol_info(fetcher, "Rails", rails_version)
        end

        if postgres_version && !postgres_version.include?("gem")
          display_eol_info(fetcher, "PostgreSQL", postgres_version)
        end

        if mysql_version && !mysql_version.include?("gem")
          display_eol_info(fetcher, "MySQL", mysql_version)
        end
      end

      # Save to config if --save flag is used
      if options[:save] && !options[:recursive]
        save_to_config(project_path, ruby_version, rails_version, postgres_version, mysql_version)
      elsif options[:save] && options[:recursive]
        # In recursive mode, save without the confirmation message for each project
        config_manager = ConfigManager.new
        project_name = File.basename(project_path)
        config_manager.save_project(
          name: project_name,
          path: project_path,
          versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version, mysql: mysql_version }.compact
        )
      end
    end

    def save_to_config(project_path, ruby_version, rails_version, postgres_version = nil, mysql_version = nil)
      config_manager = ConfigManager.new
      project_name = File.basename(project_path)

      config_manager.save_project(
        name: project_name,
        path: project_path,
        versions: { ruby: ruby_version, rails: rails_version, postgres: postgres_version, mysql: mysql_version }.compact
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
      if days < 0
        :red
      elsif days < 180 # < 6 months
        :yellow
      else
        :green
      end
    end

    def eol_status(days)
      if days < 0
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
  end
end
