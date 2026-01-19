# frozen_string_literal: true

require_relative "database_detector"

module Harbinger
  module Analyzers
    # Detects PostgreSQL version from Rails projects
    class PostgresDetector < DatabaseDetector
      protected

      def adapter_name
        "postgresql"
      end

      def detect_from_shell
        # Skip shell command if database is remote
        # (shell gives client version, not server version)
        return nil if remote_database?

        output = execute_command("psql --version")
        return nil unless output

        # Parse: "psql (PostgreSQL) 15.3" or "psql (PostgreSQL) 15.3 (Ubuntu 15.3-1)"
        match = output.match(/PostgreSQL\)\s+(\d+\.\d+)/)
        match[1] if match
      end

      def detect_from_gemfile_lock
        content = parse_gemfile_lock
        version = extract_gem_version(content, "pg")
        version ? "#{version} (pg gem)" : nil
      end

      private

      # Check if database configuration indicates a remote database
      def remote_database?
        config = parse_database_yml
        return false unless config

        # Get the section with database config
        section = config["production"] || config["default"] || config[config.keys.first]
        return false unless section

        # Handle multi-database config
        db_config = if section["adapter"]
                      section
                    else
                      section["primary"] || section.values.find { |v| v.is_a?(Hash) && v["adapter"] }
                    end

        return false unless db_config

        host = db_config["host"]

        # No host specified = localhost (Unix socket)
        return false if host.nil? || host.empty?

        # Explicit localhost indicators
        local_hosts = ["localhost", "127.0.0.1", "::1", "0.0.0.0"]
        !local_hosts.include?(host.to_s.downcase)
      end
    end
  end
end
