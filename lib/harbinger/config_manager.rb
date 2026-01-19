# frozen_string_literal: true

require "yaml"
require "fileutils"
require "time"

module Harbinger
  class ConfigManager
    def initialize(config_dir: default_config_dir)
      @config_dir = config_dir
      @config_file = File.join(@config_dir, "config.yml")
      FileUtils.mkdir_p(@config_dir)
    end

    def save_project(name:, path:, versions: {})
      config = load_config
      config["projects"] ||= {}

      config["projects"][name] = {
        "path" => path,
        "last_scanned" => Time.now.iso8601
      }.merge(versions.transform_keys(&:to_s))

      write_config(config)
    end

    def list_projects
      config = load_config
      config["projects"] || {}
    end

    def get_project(name)
      list_projects[name]
    end

    def remove_project(name)
      config = load_config
      return unless config["projects"]

      config["projects"].delete(name)
      write_config(config)
    end

    def project_count
      list_projects.size
    end

    private

    attr_reader :config_dir, :config_file

    def default_config_dir
      File.join(Dir.home, ".harbinger")
    end

    def load_config
      return {} unless File.exist?(config_file)

      YAML.load_file(config_file) || {}
    rescue Psych::SyntaxError, StandardError
      {}
    end

    def write_config(config)
      File.write(config_file, YAML.dump(config))
    rescue StandardError
      # Silently fail if we can't write
      nil
    end
  end
end
