# frozen_string_literal: true

require "yaml"

module Harbinger
  module Analyzers
    # Detects versions from docker-compose.yml and Dockerfile
    class DockerComposeDetector
      attr_reader :project_path

      def initialize(project_path)
        @project_path = project_path
      end

      # Extract version from a Docker image in docker-compose.yml
      # e.g., "postgres:16-alpine" => "16", "mysql:8.0" => "8.0"
      def image_version(image_pattern)
        compose = parse_docker_compose
        return nil unless compose

        services = compose["services"]
        return nil unless services

        services.each_value do |service|
          image = service["image"]
          next unless image

          if image.match?(/^#{image_pattern}[:\d]/)
            version = extract_version_from_image(image)
            return version if version
          end
        end

        nil
      end

      # Extract Ruby version from Dockerfile
      # e.g., "FROM ruby:3.4.7-slim" => "3.4.7"
      def ruby_version_from_dockerfile
        dockerfile = read_dockerfile
        return nil unless dockerfile

        # Match patterns like:
        # FROM ruby:3.4.7
        # FROM ruby:3.4.7-slim
        # FROM ruby:3.4.7-alpine
        match = dockerfile.match(/^FROM\s+ruby:(\d+\.\d+(?:\.\d+)?)/i)
        match[1] if match
      end

      # Extract Rails version from Dockerfile (rare, but possible)
      def rails_version_from_dockerfile
        dockerfile = read_dockerfile
        return nil unless dockerfile

        # Match patterns like:
        # FROM rails:7.0
        # ARG RAILS_VERSION=7.0.8
        match = dockerfile.match(/^FROM\s+rails:(\d+\.\d+(?:\.\d+)?)/i)
        return match[1] if match

        match = dockerfile.match(/RAILS_VERSION[=:](\d+\.\d+(?:\.\d+)?)/i)
        match[1] if match
      end

      # Check if docker-compose.yml exists
      def docker_compose_exists?
        docker_compose_path != nil
      end

      # Check if Dockerfile exists
      def dockerfile_exists?
        File.exist?(File.join(project_path, "Dockerfile"))
      end

      private

      def docker_compose_path
        paths = [
          File.join(project_path, "docker-compose.yml"),
          File.join(project_path, "docker-compose.yaml"),
          File.join(project_path, "compose.yml"),
          File.join(project_path, "compose.yaml")
        ]
        paths.find { |p| File.exist?(p) }
      end

      def parse_docker_compose
        path = docker_compose_path
        return nil unless path

        YAML.safe_load(File.read(path), aliases: true)
      rescue StandardError
        nil
      end

      def read_dockerfile
        path = File.join(project_path, "Dockerfile")
        return nil unless File.exist?(path)

        File.read(path)
      rescue StandardError
        nil
      end

      # Extract version number from Docker image tag
      # "postgres:16-alpine" => "16"
      # "postgres:16.2" => "16.2"
      # "mysql:8.0.33" => "8.0.33"
      # "redis:7-alpine" => "7"
      def extract_version_from_image(image)
        return nil unless image.include?(":")

        tag = image.split(":").last
        # Extract leading version number (digits and dots)
        match = tag.match(/^(\d+(?:\.\d+)*)/)
        match[1] if match
      end
    end
  end
end
