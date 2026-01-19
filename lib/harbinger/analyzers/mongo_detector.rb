# frozen_string_literal: true

require_relative "docker_compose_detector"

module Harbinger
  module Analyzers
    # Detects MongoDB version from projects
    class MongoDetector
      attr_reader :project_path

      def initialize(project_path)
        @project_path = project_path
      end

      # Main detection method - returns version string or nil
      def detect
        return nil unless mongo_detected?

        # Try docker-compose.yml first
        version = detect_from_docker_compose
        return version if version

        # Try shell command
        version = detect_from_shell
        return version if version

        # Fallback to gem version
        detect_from_gemfile_lock
      end

      # Check if MongoDB is used in this project
      def mongo_detected?
        gemfile_has_mongo? || docker_compose_has_mongo?
      end

      private

      def detect_from_docker_compose
        docker = DockerComposeDetector.new(project_path)
        docker.image_version("mongo")
      end

      def detect_from_shell
        # Try mongosh first (modern shell, MongoDB 5+)
        output = `mongosh --version 2>&1`.strip
        return output if $CHILD_STATUS.success? && output.match?(/^\d+\.\d+/)

        # Try legacy mongo shell
        output = `mongo --version 2>&1`.strip
        if $CHILD_STATUS.success?
          match = output.match(/MongoDB shell version v?(\d+\.\d+(?:\.\d+)?)/)
          return match[1] if match
        end

        # Fall back to mongod (server)
        output = `mongod --version 2>&1`.strip
        return nil unless $CHILD_STATUS.success?

        match = output.match(/db version v(\d+\.\d+(?:\.\d+)?)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def detect_from_gemfile_lock
        content = read_gemfile_lock
        return nil unless content

        # Look for mongoid gem version first (most common for Rails)
        match = content.match(/^\s{4}mongoid\s+\(([^)]+)\)/)
        return "#{match[1]} (mongoid gem)" if match

        # Fall back to mongo gem
        match = content.match(/^\s{4}mongo\s+\(([^)]+)\)/)
        return "#{match[1]} (mongo gem)" if match

        nil
      end

      def gemfile_has_mongo?
        content = read_gemfile_lock
        return false unless content

        content.include?("mongoid (") || content.include?("mongo (")
      end

      def docker_compose_has_mongo?
        docker = DockerComposeDetector.new(project_path)
        return false unless docker.docker_compose_exists?

        docker.image_version("mongo") != nil
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
