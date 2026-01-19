# frozen_string_literal: true

require "json"
require_relative "base_exporter"

module Harbinger
  module Exporters
    # Exports project EOL data to JSON format
    class JsonExporter < BaseExporter
      def export
        projects = build_export_data

        {
          generated_at: Time.now.iso8601,
          project_count: projects.size,
          projects: projects
        }.to_json
      end
    end
  end
end
