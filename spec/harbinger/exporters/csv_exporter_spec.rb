# frozen_string_literal: true

require "spec_helper"
require "harbinger/exporters/csv_exporter"
require "csv"

RSpec.describe Harbinger::Exporters::CsvExporter do
  let(:mock_fetcher) { instance_double(Harbinger::EolFetcher) }
  let(:projects) do
    {
      "my-app" => {
        "path" => "/path/to/my-app",
        "ruby" => "3.2.0",
        "rails" => "7.0.8"
      },
      "api-service" => {
        "path" => "/path/to/api-service",
        "ruby" => "3.1.0"
      }
    }
  end

  subject(:exporter) { described_class.new(projects, fetcher: mock_fetcher) }

  before do
    allow(mock_fetcher).to receive(:eol_date_for).with("ruby", "3.2.0").and_return("2026-03-31")
    allow(mock_fetcher).to receive(:eol_date_for).with("rails", "7.0.8").and_return("2025-06-01")
    allow(mock_fetcher).to receive(:eol_date_for).with("ruby", "3.1.0").and_return("2025-03-31")
  end

  describe "#export" do
    it "returns valid CSV" do
      result = exporter.export
      expect { CSV.parse(result) }.not_to raise_error
    end

    it "includes header row" do
      result = CSV.parse(exporter.export)
      headers = result.first

      expect(headers).to eq(%w[project path component version eol_date days_remaining status overall_status])
    end

    it "creates one row per component" do
      result = CSV.parse(exporter.export)
      # Header + 2 components for my-app (ruby, rails) + 1 component for api-service (ruby) = 4 rows
      expect(result.size).to eq(4)
    end

    it "includes project name in each row" do
      result = CSV.parse(exporter.export)
      data_rows = result[1..]

      my_app_rows = data_rows.select { |row| row[0] == "my-app" }
      expect(my_app_rows.size).to eq(2)
    end

    it "includes component details" do
      result = CSV.parse(exporter.export)
      data_rows = result[1..]

      ruby_row = data_rows.find { |row| row[0] == "my-app" && row[2] == "ruby" }
      expect(ruby_row[1]).to eq("/path/to/my-app") # path
      expect(ruby_row[3]).to eq("3.2.0") # version
      expect(ruby_row[4]).to eq("2026-03-31") # eol_date
      expect(ruby_row[5]).to match(/\A-?\d+\z/) # days_remaining (integer as string)
      expect(ruby_row[6]).to be_a(String) # status
      expect(ruby_row[7]).to be_a(String) # overall_status
    end

    it "includes overall_status in each row" do
      result = CSV.parse(exporter.export)
      data_rows = result[1..]

      data_rows.each do |row|
        expect(row[7]).to match(/\A(eol|warning|safe|unknown)\z/)
      end
    end
  end

  describe "with empty projects" do
    let(:empty_projects) { {} }

    subject(:empty_exporter) { described_class.new(empty_projects, fetcher: mock_fetcher) }

    it "returns CSV with only header row" do
      result = CSV.parse(empty_exporter.export)
      expect(result.size).to eq(1)
      expect(result.first).to eq(%w[project path component version eol_date days_remaining status overall_status])
    end
  end

  describe "HEADERS constant" do
    it "defines expected headers" do
      expect(described_class::HEADERS).to eq(%w[project path component version eol_date days_remaining status
                                                overall_status])
    end
  end
end
