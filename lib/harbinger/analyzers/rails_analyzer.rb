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

      private

      attr_reader :project_path

      def detect_from_gemfile_lock
        file_path = File.join(project_path, "Gemfile.lock")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)
        match = content.match(/^\s*rails\s+\(([^)]+)\)/)
        match ? match[1] : nil
      rescue StandardError
        nil
      end
    end
  end
end
