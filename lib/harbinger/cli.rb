# frozen_string_literal: true

require "thor"
require "date"
require_relative "version"
require "harbinger/analyzers/ruby_detector"
require "harbinger/analyzers/rails_analyzer"
require "harbinger/eol_fetcher"

module Harbinger
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "scan [PATH]", "Scan a project directory and detect versions"
    option :path, type: :string, aliases: "-p", desc: "Path to project directory"
    def scan(path = nil)
      project_path = path || options[:path] || Dir.pwd

      unless File.directory?(project_path)
        say "Error: #{project_path} is not a valid directory", :red
        exit 1
      end

      say "Scanning #{project_path}...", :cyan

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
    end

    desc "show", "Show EOL status for tracked projects"
    def show
      say "Show command coming soon!", :yellow
      say "Use 'harbinger scan' to check a project's EOL status", :white
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
  end
end
