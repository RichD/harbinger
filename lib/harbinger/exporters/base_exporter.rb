# frozen_string_literal: true

require "date"
require "harbinger/eol_fetcher"

module Harbinger
  module Exporters
    # Base class for exporters that transform project data into various formats
    class BaseExporter
      COMPONENTS = %w[ruby rails postgres mysql redis mongo python nodejs rust].freeze
      PRODUCT_NAMES = {
        "ruby" => "ruby",
        "rails" => "rails",
        "postgres" => "postgresql",
        "mysql" => "mysql",
        "redis" => "redis",
        "mongo" => "mongodb",
        "python" => "python",
        "nodejs" => "nodejs",
        "rust" => "rust"
      }.freeze

      def initialize(projects, fetcher: nil)
        @projects = projects
        @fetcher = fetcher || EolFetcher.new
      end

      def export
        raise NotImplementedError, "Subclasses must implement #export"
      end

      protected

      def build_export_data
        @projects.filter_map do |name, data|
          components = build_components(data)
          next if components.empty?

          {
            name: name,
            path: data["path"],
            components: components,
            overall_status: determine_overall_status(components)
          }
        end
      end

      private

      def build_components(data)
        COMPONENTS.filter_map do |component|
          version = data[component]
          next if version.nil? || version.empty?
          next if version.include?("gem")

          product = PRODUCT_NAMES[component]
          eol_date = @fetcher.eol_date_for(product, version)
          days = eol_date ? days_until(eol_date) : nil
          status = days ? calculate_status(days) : "unknown"

          {
            name: component,
            version: version,
            eol_date: eol_date,
            days_remaining: days,
            status: status
          }
        end
      end

      def calculate_status(days)
        if days.negative?
          "eol"
        elsif days < 180
          "warning"
        else
          "safe"
        end
      end

      def determine_overall_status(components)
        statuses = components.map { |c| c[:status] }
        return "unknown" if statuses.empty? || statuses.all? { |s| s == "unknown" }

        if statuses.include?("eol")
          "eol"
        elsif statuses.include?("warning")
          "warning"
        else
          "safe"
        end
      end

      def days_until(date_string)
        eol_date = Date.parse(date_string)
        (eol_date - Date.today).to_i
      end
    end
  end
end
