# frozen_string_literal: true

require_relative "docker_compose_detector"

module Harbinger
  module Analyzers
    class RustDetector
      def initialize(project_path)
        @project_path = project_path
      end

      def detect
        detect_from_rust_toolchain ||
          detect_from_cargo_toml ||
          detect_from_docker_compose ||
          (rust_detected? ? detect_from_shell : nil)
      end

      def rust_detected?
        File.exist?(File.join(project_path, "Cargo.toml")) ||
          File.exist?(File.join(project_path, "Cargo.lock")) ||
          File.exist?(File.join(project_path, "rust-toolchain")) ||
          File.exist?(File.join(project_path, "rust-toolchain.toml")) ||
          (File.directory?(File.join(project_path, "src")) && has_rust_files?)
      rescue StandardError
        false
      end

      private

      attr_reader :project_path

      def detect_from_rust_toolchain
        # Try rust-toolchain.toml first (TOML format)
        toml_path = File.join(project_path, "rust-toolchain.toml")
        if File.exist?(toml_path)
          content = File.read(toml_path)
          # Parse: channel = "1.75.0" or channel = "stable"
          match = content.match(/channel\s*=\s*["']([^"']+)["']/)
          if match
            channel = match[1]
            # Skip "stable", "beta", "nightly" - we need specific versions
            return extract_version(channel) unless channel =~ /^(stable|beta|nightly)$/
          end
        end

        # Try plain rust-toolchain file
        plain_path = File.join(project_path, "rust-toolchain")
        if File.exist?(plain_path)
          content = File.read(plain_path).strip
          return extract_version(content) unless content.empty? || content =~ /^(stable|beta|nightly)$/
        end

        nil
      rescue StandardError
        nil
      end

      def detect_from_cargo_toml
        file_path = File.join(project_path, "Cargo.toml")
        return nil unless File.exist?(file_path)

        content = File.read(file_path)

        # Parse: rust-version = "1.70" or rust-version = "1.70.0"
        # This is the MSRV (Minimum Supported Rust Version)
        match = content.match(/rust-version\s*=\s*["']([^"']+)["']/)
        return extract_version(match[1]) if match

        nil
      rescue StandardError
        nil
      end

      def detect_from_docker_compose
        docker = DockerComposeDetector.new(project_path)
        docker.image_version("rust")
      end

      def detect_from_shell
        output = `rustc --version 2>&1`.strip
        return nil unless $CHILD_STATUS.success?

        # Parse: "rustc 1.75.0 (82e1608df 2023-12-21)"
        match = output.match(/rustc\s+(\d+\.\d+(?:\.\d+)?)/)
        match[1] if match
      rescue StandardError
        nil
      end

      def extract_version(version_string)
        # Remove "rust-" prefix if present
        version = version_string.sub(/^rust-/, "")

        # Strip any whitespace
        version = version.strip

        # Handle version with date: "1.75.0-2023-12-21" -> "1.75.0"
        version = version.split("-").first if version.include?("-")

        # Return major.minor or major.minor.patch format
        # endoflife.date uses "1.75" format, but "1.75.0" also works
        version
      end

      def has_rust_files?
        src_dir = File.join(project_path, "src")
        return false unless File.directory?(src_dir)

        Dir.glob(File.join(src_dir, "**/*.rs")).any?
      rescue StandardError
        false
      end
    end
  end
end
