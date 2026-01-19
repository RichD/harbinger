# frozen_string_literal: true

require "csv"
require_relative "base_exporter"

module Harbinger
  module Exporters
    # Exports project EOL data to CSV format
    class CsvExporter < BaseExporter
      HEADERS = %w[project path component version eol_date days_remaining status overall_status].freeze

      def export
        projects = build_export_data

        CSV.generate do |csv|
          csv << HEADERS

          projects.each do |project|
            project[:components].each do |component|
              csv << [
                project[:name],
                project[:path],
                component[:name],
                component[:version],
                component[:eol_date],
                component[:days_remaining],
                component[:status],
                project[:overall_status]
              ]
            end
          end
        end
      end
    end
  end
end
