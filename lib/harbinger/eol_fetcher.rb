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
      return read_cache(cache_file) if cache_fresh?(cache_file)

      # Try to fetch from API
      begin
        data = fetch_from_api(product)
        write_cache(cache_file, data)
        data
      rescue StandardError
        # Fall back to stale cache if API fails
        read_cache(cache_file) if File.exist?(cache_file)
      end
    end

    def eol_date_for(product, version)
      data = fetch(product)
      return nil unless data

      # Extract major.minor from version (e.g., "3.2.1" -> "3.2")
      version_parts = version.split(".")
      major = version_parts[0]
      major_minor = version_parts[1] ? "#{major}.#{version_parts[1]}" : nil

      # Try exact major.minor first (e.g., "8.0" for MySQL, "3.2" for Ruby)
      if major_minor
        entry = data.find { |item| item["cycle"] == major_minor }
        return entry["eol"] if entry
      end

      # Try major only (e.g., "16" for PostgreSQL)
      entry = data.find { |item| item["cycle"] == major }
      return entry["eol"] if entry

      # For major-only versions, find the latest minor version in that major series
      # (e.g., version "7" should match "7.4" which is the latest 7.x)
      matching_entries = data.select { |item| item["cycle"].to_s.start_with?("#{major}.") }
      return nil if matching_entries.empty?

      # Sort by cycle version and get the latest (highest minor version)
      latest = matching_entries.max_by { |item| item["cycle"].to_s.split(".").map(&:to_i) }
      latest ? latest["eol"] : nil
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
