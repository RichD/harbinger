# frozen_string_literal: true

require_relative "docker_compose_detector"

module Harbinger
  module Analyzers
    # Detects Redis version from projects
    class RedisDetector
      attr_reader :project_path

      def initialize(project_path)
        @project_path = project_path
      end

      # Main detection method - returns version string or nil
      def detect
        return nil unless redis_detected?

        # Try docker-compose.yml first
        version = detect_from_docker_compose
        return version if version

        # Try shell command
        version = detect_from_shell
        return version if version

        # Fallback to gem version
        detect_from_gemfile_lock
      end

      # Check if Redis is used in this project
      def redis_detected?
        gemfile_has_redis? || docker_compose_has_redis?
      end

      private

      def detect_from_docker_compose
        docker = DockerComposeDetector.new(project_path)
        docker.image_version("redis")
      end

      def detect_from_shell
        # Try redis-cli first (more commonly available)
        output = `redis-cli -v 2>&1`.strip
        if $CHILD_STATUS.success?
          # Parse: "redis-cli 7.0.5"
          match = output.match(/redis-cli\s+(\d+\.\d+(?:\.\d+)?)/)
          return match[1] if match
        end

        # Fall back to redis-server
        output = `redis-server --version 2>&1`.strip
        return nil unless $CHILD_STATUS.success?

        # Parse: "Redis server v=7.2.4 sha=..."
        match = output.match(/v=(\d+\.\d+(?:\.\d+)?)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def detect_from_gemfile_lock
        content = read_gemfile_lock
        return nil unless content

        # Look for redis gem version
        match = content.match(/^\s{4}redis\s+\(([^)]+)\)/)
        return "#{match[1]} (gem)" if match

        nil
      end

      def gemfile_has_redis?
        content = read_gemfile_lock
        return false unless content

        content.include?("redis (")
      end

      def docker_compose_has_redis?
        docker = DockerComposeDetector.new(project_path)
        return false unless docker.docker_compose_exists?

        docker.image_version("redis") != nil
      end

      def read_gemfile_lock
        path = File.join(project_path, "Gemfile.lock")
        return nil unless File.exist?(path)

        File.read(path)
      rescue StandardError
        nil
      end
    end
  end
end
