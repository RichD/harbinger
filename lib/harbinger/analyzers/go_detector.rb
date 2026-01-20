# frozen_string_literal: true

module Harbinger
  module Analyzers
    class GoDetector
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        version = detect_from_go_mod ||
                  detect_from_go_work ||
                  detect_from_go_version_file ||
                  detect_from_docker_compose ||
                  detect_from_shell

        normalize_version(version) if version
      end

      def go_detected?
        File.exist?(File.join(@project_path, "go.mod")) ||
          File.exist?(File.join(@project_path, "go.work")) ||
          File.exist?(File.join(@project_path, ".go-version"))
      end

      private

      def detect_from_go_mod
        go_mod_path = File.join(@project_path, "go.mod")
        return nil unless File.exist?(go_mod_path)

        content = File.read(go_mod_path)
        # Match "go 1.21" or "go 1.21.0" format
        match = content.match(/^go\s+([\d.]+)/m)
        match[1] if match
      end

      def detect_from_go_work
        go_work_path = File.join(@project_path, "go.work")
        return nil unless File.exist?(go_work_path)

        content = File.read(go_work_path)
        # Match "go 1.21" or "go 1.21.0" format
        match = content.match(/^go\s+([\d.]+)/m)
        match[1] if match
      end

      def detect_from_go_version_file
        go_version_path = File.join(@project_path, ".go-version")
        return nil unless File.exist?(go_version_path)

        version = File.read(go_version_path).strip
        version unless version.empty?
      end

      def detect_from_docker_compose
        docker_compose_path = File.join(@project_path, "docker-compose.yml")
        return nil unless File.exist?(docker_compose_path)

        content = File.read(docker_compose_path)
        # Match golang:1.21, golang:1.21.0, golang:1.21-alpine, etc.
        match = content.match(/golang:([\d.]+)/)
        match[1] if match
      end

      def detect_from_shell
        # Only try shell detection if Go project files exist
        return nil unless go_detected?

        version_output = `go version 2>/dev/null`.strip
        return nil if version_output.empty?

        # Parse "go version go1.21.0 darwin/amd64" format
        match = version_output.match(/go version go([\d.]+)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def normalize_version(version)
        # Remove any trailing qualifiers like -alpine, -rc1, etc.
        version.gsub(/-(alpine|rc\d+|beta\d*).*/, "")
      end
    end
  end
end
