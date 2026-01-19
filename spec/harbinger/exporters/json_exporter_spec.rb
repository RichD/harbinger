# frozen_string_literal: true

require "spec_helper"
require "harbinger/exporters/json_exporter"
require "json"

RSpec.describe Harbinger::Exporters::JsonExporter do
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
        "ruby" => "3.1.0",
        "postgres" => "15.0"
      }
    }
  end

  subject(:exporter) { described_class.new(projects, fetcher: mock_fetcher) }

  before do
    allow(mock_fetcher).to receive(:eol_date_for).with("ruby", "3.2.0").and_return("2026-03-31")
    allow(mock_fetcher).to receive(:eol_date_for).with("rails", "7.0.8").and_return("2025-06-01")
    allow(mock_fetcher).to receive(:eol_date_for).with("ruby", "3.1.0").and_return("2025-03-31")
    allow(mock_fetcher).to receive(:eol_date_for).with("postgresql", "15.0").and_return("2027-11-11")
  end

  describe "#export" do
    it "returns valid JSON" do
      result = exporter.export
      expect { JSON.parse(result) }.not_to raise_error
    end

    it "includes generated_at timestamp" do
      result = JSON.parse(exporter.export)
      expect(result["generated_at"]).to be_a(String)
      expect { Time.iso8601(result["generated_at"]) }.not_to raise_error
    end

    it "includes project_count" do
      result = JSON.parse(exporter.export)
      expect(result["project_count"]).to eq(2)
    end

    it "includes projects array" do
      result = JSON.parse(exporter.export)
      expect(result["projects"]).to be_an(Array)
      expect(result["projects"].size).to eq(2)
    end

    it "includes project details" do
      result = JSON.parse(exporter.export)
      project = result["projects"].find { |p| p["name"] == "my-app" }

      expect(project["path"]).to eq("/path/to/my-app")
      expect(project["overall_status"]).to be_a(String)
    end

    it "includes component details" do
      result = JSON.parse(exporter.export)
      project = result["projects"].find { |p| p["name"] == "my-app" }
      ruby_component = project["components"].find { |c| c["name"] == "ruby" }

      expect(ruby_component["version"]).to eq("3.2.0")
      expect(ruby_component["eol_date"]).to eq("2026-03-31")
      expect(ruby_component["days_remaining"]).to be_a(Integer)
      expect(ruby_component["status"]).to be_a(String)
    end
  end

  describe "with empty projects" do
    let(:empty_projects) { {} }

    subject(:empty_exporter) { described_class.new(empty_projects, fetcher: mock_fetcher) }

    it "returns valid JSON with empty projects array" do
      result = JSON.parse(empty_exporter.export)
      expect(result["project_count"]).to eq(0)
      expect(result["projects"]).to eq([])
    end
  end
end
