# frozen_string_literal: true

module Harbinger
  module Analyzers
    class PythonDetector
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        detect_from_pyproject_toml ||
          detect_from_python_version ||
          detect_from_pyvenv_cfg ||
          (python_detected? ? detect_from_shell : nil)
      end

      def python_detected?
        File.exist?(File.join(project_path, "pyproject.toml")) ||
          File.exist?(File.join(project_path, "requirements.txt")) ||
          File.exist?(File.join(project_path, ".python-version")) ||
          File.exist?(File.join(project_path, "setup.py")) ||
          File.exist?(File.join(project_path, "setup.cfg")) ||
          venv_exists?
      end

      private

      attr_reader :project_path

      def detect_from_pyproject_toml
        file_path = File.join(project_path, "pyproject.toml")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)

        # Try [project] requires-python = ">=3.11"
        match = content.match(/requires-python\s*=\s*["']([^"']+)["']/)
        return extract_version(match[1]) if match

        # Try [tool.poetry.dependencies] python = "^3.11"
        match = content.match(/\[tool\.poetry\.dependencies\].*?python\s*=\s*["']([^"']+)["']/m)
        return extract_version(match[1]) if match

        nil
      rescue StandardError
        nil
      end

      def detect_from_python_version
        file_path = File.join(project_path, ".python-version")
        return nil unless File.exist?(file_path)

        content = File.read(file_path).strip
        extract_version(content)
      rescue StandardError
        nil
      end

      def detect_from_pyvenv_cfg
        ["venv/pyvenv.cfg", ".venv/pyvenv.cfg"].each do |cfg_path|
          file_path = File.join(project_path, cfg_path)
          next unless File.exist?(file_path)

          content = File.read(file_path)
          # Parse: "version = 3.11.5"
          match = content.match(/version\s*=\s*(\d+\.\d+(?:\.\d+)?)/)
          return match[1] if match
        end

        nil
      rescue StandardError
        nil
      end

      def detect_from_shell
        # Try python3 first (more reliable on multi-Python systems)
        output = `python3 --version 2>&1`.strip
        if $CHILD_STATUS.success?
          match = output.match(/Python\s+(\d+\.\d+(?:\.\d+)?)/)
          return match[1] if match
        end

        # Fall back to python
        output = `python --version 2>&1`.strip
        return nil unless $CHILD_STATUS.success?

        match = output.match(/Python\s+(\d+\.\d+(?:\.\d+)?)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def extract_version(version_string)
        # Strip constraint operators: >=3.11, ^3.11, ~3.11, >3.11, <4.0
        version = version_string.gsub(/^[><=~^!\s]+/, "")

        # Handle ranges like ">=3.9,<4.0" - extract first version
        version = version.split(",").first.strip if version.include?(",")

        # Remove "python-" prefix if present (from .python-version)
        version.sub(/^python-/, "")
      end

      def venv_exists?
        File.exist?(File.join(project_path, "venv/pyvenv.cfg")) ||
          File.exist?(File.join(project_path, ".venv/pyvenv.cfg"))
      end
    end
  end
end
