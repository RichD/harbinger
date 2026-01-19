# frozen_string_literal: true

require "yaml"

module Harbinger
  module Analyzers
    # Abstract base class for database version detection in Rails projects
    # Provides common functionality for detecting database versions from Rails projects
    class DatabaseDetector
      attr_reader :project_path

      def initialize(project_path)
        @project_path = project_path
      end

      # Main detection method - returns version string or nil
      def detect
        return nil unless database_detected?

        # Try shell command first (actual database version)
        version = detect_from_shell
        return version if version

        # Fallback to gem version from Gemfile.lock
        detect_from_gemfile_lock
      end

      # Check if database.yml indicates this database is used
      def database_detected?
        return false unless database_yml_exists?

        config = parse_database_yml
        return false unless config

        # Check production or default section
        section = config["production"] || config["default"] || config[config.keys.first]
        return false unless section

        adapter = extract_adapter_from_section(section)
        return false unless adapter

        Array(adapter_name).any? { |name| adapter == name }
      end

      protected

      # Extract adapter from database config section
      # Handles both single-database and multi-database (Rails 6+) configurations
      def extract_adapter_from_section(section)
        # Single database: { "adapter" => "postgresql", ... }
        return section["adapter"] if section["adapter"]

        # Multi-database: { "primary" => { "adapter" => "postgresql", ... }, "cache" => { ... } }
        # Check primary first, then fall back to first nested config
        nested_config = section["primary"] || section.values.find { |v| v.is_a?(Hash) && v["adapter"] }
        nested_config["adapter"] if nested_config
      end

      # Abstract method - must be implemented by subclasses
      # Returns the adapter name(s) to look for in database.yml
      def adapter_name
        raise NotImplementedError, "Subclasses must implement adapter_name"
      end

      # Abstract method - must be implemented by subclasses
      # Detects version from shell command (e.g., psql --version)
      def detect_from_shell
        raise NotImplementedError, "Subclasses must implement detect_from_shell"
      end

      # Abstract method - must be implemented by subclasses
      # Detects version from Gemfile.lock gem version
      def detect_from_gemfile_lock
        raise NotImplementedError, "Subclasses must implement detect_from_gemfile_lock"
      end

      # Read and parse config/database.yml
      def parse_database_yml
        database_yml_path = File.join(project_path, "config", "database.yml")
        return nil unless File.exist?(database_yml_path)

        content = File.read(database_yml_path)
        YAML.safe_load(content, aliases: true)
      rescue Psych::SyntaxError, StandardError
        nil
      end

      # Check if database.yml exists
      def database_yml_exists?
        File.exist?(File.join(project_path, "config", "database.yml"))
      end

      # Read and parse Gemfile.lock
      def parse_gemfile_lock
        gemfile_lock_path = File.join(project_path, "Gemfile.lock")
        return nil unless File.exist?(gemfile_lock_path)

        File.read(gemfile_lock_path)
      rescue StandardError
        nil
      end

      # Extract gem version from Gemfile.lock content
      def extract_gem_version(gemfile_lock_content, gem_name)
        return nil unless gemfile_lock_content

        # Match pattern like: "    pg (1.5.4)"
        match = gemfile_lock_content.match(/^\s{4}#{Regexp.escape(gem_name)}\s+\(([^)]+)\)/)
        match[1] if match
      end

      # Execute shell command safely
      def execute_command(command)
        output = `#{command} 2>&1`.strip
        return nil unless $?.success?

        output
      rescue StandardError
        nil
      end
    end
  end
end
