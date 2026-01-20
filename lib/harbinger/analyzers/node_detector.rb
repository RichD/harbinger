# frozen_string_literal: true

require_relative "docker_compose_detector"
require "json"

module Harbinger
  module Analyzers
    class NodeDetector
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        detect_from_version_files ||
          detect_from_package_json ||
          detect_from_docker_compose ||
          detect_from_shell
      end

      def nodejs_detected?
        File.exist?(File.join(project_path, "package.json")) ||
          File.exist?(File.join(project_path, "package-lock.json")) ||
          File.exist?(File.join(project_path, ".nvmrc")) ||
          File.exist?(File.join(project_path, ".node-version")) ||
          File.exist?(File.join(project_path, "node_modules"))
      rescue StandardError
        false
      end

      private

      attr_reader :project_path

      def detect_from_version_files
        [".nvmrc", ".node-version"].each do |filename|
          file_path = File.join(project_path, filename)
          next unless File.exist?(file_path)

          content = File.read(file_path).strip
          next if content.empty?

          return extract_version(content)
        end

        nil
      rescue StandardError
        nil
      end

      def detect_from_package_json
        file_path = File.join(project_path, "package.json")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)
        package = JSON.parse(content)

        engines = package.dig("engines", "node")
        return nil unless engines

        extract_version(engines)
      rescue StandardError
        nil
      end

      def detect_from_docker_compose
        docker = DockerComposeDetector.new(project_path)
        docker.image_version("node")
      end

      def detect_from_shell
        output = `node --version 2>&1`.strip
        return nil unless $CHILD_STATUS.success?

        # Parse: "v18.16.0" (note the 'v' prefix)
        match = output.match(/^v?(\d+\.\d+(?:\.\d+)?)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def extract_version(version_string)
        # Remove 'v' prefix (Node.js convention)
        version = version_string.sub(/^v/, "")

        # Strip constraint operators: >=18.0.0, ^18.0.0, ~18.0.0
        version = version.gsub(/^[><=~^!\s]+/, "")

        # Handle ranges like ">=14.0.0 <20.0.0" - extract first version
        version = version.split(/\s+/).first if version.include?(" ")

        # Handle .x suffix (e.g., "18.x" => "18")
        version = version.sub(/\.x$/, "")

        # Handle LTS names like "lts/hydrogen" (hydrogen=18, gallium=16, fermium=14)
        if version =~ /lts\/(hydrogen|gallium|fermium)/i
          lts_name = $1.downcase
          return case lts_name
                 when "hydrogen" then "18"
                 when "gallium" then "16"
                 when "fermium" then "14"
                 else nil
                 end
        end

        version
      end
    end
  end
end
