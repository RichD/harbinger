# frozen_string_literal: true

require "httparty"
require "json"
require "fileutils"

module Harbinger
  class EolFetcher
    CACHE_EXPIRY_SECONDS = 24 * 60 * 60 # 24 hours
    API_BASE_URL = "https://endoflife.date/api"

    def initialize(cache_dir: default_cache_dir)
      @cache_dir = cache_dir
      FileUtils.mkdir_p(@cache_dir)
    end

    def fetch(product)
      cache_file = cache_file_path(product)

      # Return fresh cache if available
      if cache_fresh?(cache_file)
        return read_cache(cache_file)
      end

      # Try to fetch from API
      begin
        data = fetch_from_api(product)
        write_cache(cache_file, data)
        data
      rescue StandardError => e
        # Fall back to stale cache if API fails
        read_cache(cache_file) if File.exist?(cache_file)
      end
    end

    def eol_date_for(product, version)
      data = fetch(product)
      return nil unless data

      # Extract major.minor from version (e.g., "3.2.1" -> "3.2")
      version_parts = version.split(".")
      major_minor = "#{version_parts[0]}.#{version_parts[1]}"

      # Find matching cycle
      entry = data.find { |item| item["cycle"] == major_minor }
      entry ? entry["eol"] : nil
    end

    private

    attr_reader :cache_dir

    def default_cache_dir
      File.join(Dir.home, ".harbinger", "data")
    end

    def cache_file_path(product)
      File.join(cache_dir, "#{product}.json")
    end

    def cache_fresh?(cache_file)
      return false unless File.exist?(cache_file)

      File.mtime(cache_file) > Time.now - CACHE_EXPIRY_SECONDS
    end

    def read_cache(cache_file)
      return nil unless File.exist?(cache_file)

      JSON.parse(File.read(cache_file))
    rescue StandardError
      nil
    end

    def write_cache(cache_file, data)
      File.write(cache_file, JSON.pretty_generate(data))
    rescue StandardError
      # Silently fail if we can't write cache
      nil
    end

    def fetch_from_api(product)
      url = "#{API_BASE_URL}/#{product}.json"
      response = HTTParty.get(url)

      raise "API request failed: #{response.code}" unless response.success?

      response.parsed_response
    end
  end
end
