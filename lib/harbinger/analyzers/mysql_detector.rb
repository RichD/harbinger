# frozen_string_literal: true

require_relative "database_detector"
require_relative "docker_compose_detector"

module Harbinger
  module Analyzers
    # Detects MySQL version from Rails projects
    # Supports both mysql2 and trilogy adapters
    class MysqlDetector < DatabaseDetector
      protected

      def adapter_name
        %w[mysql2 trilogy]
      end

      def detect_from_docker_compose
        docker = DockerComposeDetector.new(project_path)
        # Try mysql first, then mariadb
        docker.image_version("mysql") || docker.image_version("mariadb")
      end

      def detect_from_shell
        # Skip shell command if database is remote
        return nil if remote_database?

        # Try mysql command first, then mysqld
        output = execute_command("mysql --version") || execute_command("mysqld --version")
        return nil unless output

        # Parse: "mysql  Ver 8.0.33" or "mysqld  Ver 8.0.33"
        # Also handles MariaDB: "mysql  Ver 15.1 Distrib 10.11.2-MariaDB"
        match = output.match(/Ver\s+(?:\d+\.\d+\s+Distrib\s+)?(\d+\.\d+\.\d+)/)
        match[1] if match
      end

      def detect_from_gemfile_lock
        content = parse_gemfile_lock
        return nil unless content

        # Check which adapter is being used
        config = parse_database_yml
        return nil unless config

        section = config["production"] || config["default"] || config[config.keys.first]
        return nil unless section

        adapter = extract_adapter_from_section(section)

        # Return appropriate gem version based on adapter
        if adapter == "trilogy"
          version = extract_gem_version(content, "trilogy")
          version ? "#{version} (trilogy gem)" : nil
        else
          version = extract_gem_version(content, "mysql2")
          version ? "#{version} (mysql2 gem)" : nil
        end
      end

      private

      # Check if database configuration indicates a remote database
      # (same logic as PostgresDetector)
      def remote_database?
        config = parse_database_yml
        return false unless config

        section = config["production"] || config["default"] || config[config.keys.first]
        return false unless section

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
