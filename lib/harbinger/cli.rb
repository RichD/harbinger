# frozen_string_literal: true

require "thor"
require "date"
require "tty-table"
require_relative "version"
require "harbinger/analyzers/ruby_detector"
require "harbinger/analyzers/rails_analyzer"
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

        ruby_display = ruby_version && !ruby_version.empty? ? ruby_version : "-"
        rails_display = rails_version && !rails_version.empty? ? rails_version : "-"

        rows << [name, ruby_display, rails_display, colorize_status(status_text, worst_status)]
      end

      # Sort by status priority (worst first), then by name
      rows.sort_by! do |row|
        status = row[3]
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
        header: ["Project", "Ruby", "Rails", "Status"],
        rows: rows
      )

      puts table.render(:unicode, padding: [0, 1])

      say "\nUse 'harbinger scan --path <project>' to update a project", :cyan
    end

    desc "update", "Force refresh EOL data from endoflife.date"
    def update
      say "Updating EOL data...", :cyan

      fetcher = EolFetcher.new
      products = %w[ruby rails]

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

      ruby_version = ruby_detector.detect
      rails_version = rails_analyzer.detect

      ruby_present = ruby_detector.ruby_detected?
      rails_present = rails_analyzer.rails_detected?

      # Display results
      say "\nDetected versions:", :green
      if ruby_version
        say "  Ruby:  #{ruby_version}", :white
      elsif ruby_present
        say "  Ruby:  Present (version not specified - add .ruby-version or ruby declaration in Gemfile)", :yellow
      else
        say "  Ruby:  Not a Ruby project", :red
      end

      if rails_version
        say "  Rails: #{rails_version}", :white
      elsif rails_present
        say "  Rails: Present (version not found in Gemfile.lock)", :yellow
      else
        say "  Rails: Not detected", :yellow
      end

      # Fetch and display EOL dates
      if ruby_version || rails_version
        say "\nFetching EOL data...", :cyan
        fetcher = EolFetcher.new

        if ruby_version
          display_eol_info(fetcher, "Ruby", ruby_version)
        end

        if rails_version
          display_eol_info(fetcher, "Rails", rails_version)
        end
      end

      # Save to config if --save flag is used
      if options[:save] && !options[:recursive]
        save_to_config(project_path, ruby_version, rails_version)
      elsif options[:save] && options[:recursive]
        # In recursive mode, save without the confirmation message for each project
        config_manager = ConfigManager.new
        project_name = File.basename(project_path)
        config_manager.save_project(
          name: project_name,
          path: project_path,
          versions: { ruby: ruby_version, rails: rails_version }.compact
        )
      end
    end

    def save_to_config(project_path, ruby_version, rails_version)
      config_manager = ConfigManager.new
      project_name = File.basename(project_path)

      config_manager.save_project(
        name: project_name,
        path: project_path,
        versions: { ruby: ruby_version, rails: rails_version }.compact
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
