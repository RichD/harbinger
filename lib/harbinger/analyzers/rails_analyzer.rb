# frozen_string_literal: true

module Harbinger
  module Analyzers
    class RailsAnalyzer
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        detect_from_gemfile_lock
      end

      def rails_detected?
        gemfile_lock = File.join(project_path, "Gemfile.lock")
        return false unless File.exist?(gemfile_lock)

        content = File.read(gemfile_lock)
        content.match?(/^\s*rails\s+\(/)
      rescue StandardError
        false
      end

      private

      attr_reader :project_path

      def detect_from_gemfile_lock
        file_path = File.join(project_path, "Gemfile.lock")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)
        match = content.match(/^\s*rails\s+\(([^)]+)\)/)
        return nil unless match

        version_string = match[1]
        # Strip version constraint operators (>=, ~>, =, etc.) and extract actual version
        version_string.sub(/^[><=~!\s]+/, "").strip
      rescue StandardError
        nil
      end
    end
  end
end
