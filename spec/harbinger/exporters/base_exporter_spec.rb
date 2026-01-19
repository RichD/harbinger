# frozen_string_literal: true

require "spec_helper"
require "harbinger/exporters/base_exporter"

RSpec.describe Harbinger::Exporters::BaseExporter do
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
    it "raises NotImplementedError" do
      expect { exporter.export }.to raise_error(NotImplementedError)
    end
  end

  describe "#build_export_data (via subclass)" do
    # Create a test subclass to access protected method
    let(:test_exporter_class) do
      Class.new(described_class) do
        def export
          build_export_data
        end
      end
    end

    subject(:test_exporter) { test_exporter_class.new(projects, fetcher: mock_fetcher) }

    it "builds export data for all projects" do
      data = test_exporter.export
      expect(data.size).to eq(2)
    end

    it "includes project name and path" do
      data = test_exporter.export
      project = data.find { |p| p[:name] == "my-app" }
      expect(project[:path]).to eq("/path/to/my-app")
    end

    it "includes components with version and eol info" do
      data = test_exporter.export
      project = data.find { |p| p[:name] == "my-app" }
      ruby_component = project[:components].find { |c| c[:name] == "ruby" }

      expect(ruby_component[:version]).to eq("3.2.0")
      expect(ruby_component[:eol_date]).to eq("2026-03-31")
      expect(ruby_component[:days_remaining]).to be_a(Integer)
      expect(ruby_component[:status]).to be_a(String)
    end

    it "determines overall status based on components" do
      data = test_exporter.export
      project = data.find { |p| p[:name] == "my-app" }
      expect(project[:overall_status]).to be_a(String)
    end

    it "filters out gem-only versions" do
      projects_with_gem = {
        "test" => {
          "path" => "/path/to/test",
          "postgres" => "pg gem 1.5.0"
        }
      }
      gem_exporter = test_exporter_class.new(projects_with_gem, fetcher: mock_fetcher)
      data = gem_exporter.export
      expect(data).to be_empty
    end

    it "skips projects with no valid components" do
      projects_empty = {
        "empty" => {
          "path" => "/path/to/empty"
        }
      }
      empty_exporter = test_exporter_class.new(projects_empty, fetcher: mock_fetcher)
      data = empty_exporter.export
      expect(data).to be_empty
    end
  end

  describe "status calculation" do
    let(:test_exporter_class) do
      Class.new(described_class) do
        def test_calculate_status(days)
          calculate_status(days)
        end

        def test_determine_overall_status(components)
          determine_overall_status(components)
        end

        def export
          nil
        end
      end
    end

    subject(:test_exporter) { test_exporter_class.new({}, fetcher: mock_fetcher) }

    describe "#calculate_status" do
      it "returns 'eol' for negative days" do
        expect(test_exporter.test_calculate_status(-10)).to eq("eol")
      end

      it "returns 'warning' for days < 180" do
        expect(test_exporter.test_calculate_status(90)).to eq("warning")
        expect(test_exporter.test_calculate_status(179)).to eq("warning")
      end

      it "returns 'safe' for days >= 180" do
        expect(test_exporter.test_calculate_status(180)).to eq("safe")
        expect(test_exporter.test_calculate_status(365)).to eq("safe")
      end
    end

    describe "#determine_overall_status" do
      it "returns 'eol' if any component is eol" do
        components = [
          { status: "safe" },
          { status: "eol" },
          { status: "warning" }
        ]
        expect(test_exporter.test_determine_overall_status(components)).to eq("eol")
      end

      it "returns 'warning' if any component is warning (no eol)" do
        components = [
          { status: "safe" },
          { status: "warning" }
        ]
        expect(test_exporter.test_determine_overall_status(components)).to eq("warning")
      end

      it "returns 'safe' if all components are safe" do
        components = [
          { status: "safe" },
          { status: "safe" }
        ]
        expect(test_exporter.test_determine_overall_status(components)).to eq("safe")
      end

      it "returns 'unknown' if all components are unknown" do
        components = [
          { status: "unknown" },
          { status: "unknown" }
        ]
        expect(test_exporter.test_determine_overall_status(components)).to eq("unknown")
      end

      it "returns 'unknown' for empty components" do
        expect(test_exporter.test_determine_overall_status([])).to eq("unknown")
      end
    end
  end
end
