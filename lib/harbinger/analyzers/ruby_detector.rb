# frozen_string_literal: true

module Harbinger
  module Analyzers
    class RubyDetector
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        detect_from_ruby_version ||
          detect_from_gemfile ||
          detect_from_gemfile_lock
      end

      def ruby_detected?
        File.exist?(File.join(project_path, "Gemfile")) ||
          File.exist?(File.join(project_path, "Gemfile.lock")) ||
          File.exist?(File.join(project_path, ".ruby-version"))
      end

      private

      attr_reader :project_path

      def detect_from_ruby_version
        file_path = File.join(project_path, ".ruby-version")
        return nil unless File.exist?(file_path)

        content = File.read(file_path).strip
        extract_version(content)
      rescue StandardError
        nil
      end

      def detect_from_gemfile
        file_path = File.join(project_path, "Gemfile")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)
        match = content.match(/ruby\s+["']([^"']+)["']/)
        match ? match[1] : nil
      rescue StandardError
        nil
      end

      def detect_from_gemfile_lock
        file_path = File.join(project_path, "Gemfile.lock")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)
        match = content.match(/RUBY VERSION\s+ruby\s+([^\s]+)/)
        match ? extract_version(match[1]) : nil
      rescue StandardError
        nil
      end

      def extract_version(version_string)
        # Remove "ruby-" prefix if present
        version = version_string.sub(/^ruby-/, "")
        # Remove patch level suffix (e.g., "p223")
        version.sub(/p\d+$/, "")
      end
    end
  end
end
