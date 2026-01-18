# frozen_string_literal: true

require "spec_helper"
require "harbinger/eol_fetcher"
require "json"
require "net/http"

RSpec.describe Harbinger::EolFetcher do
  let(:cache_dir) { "/tmp/harbinger_test" }
  subject(:fetcher) { described_class.new(cache_dir: cache_dir) }

  let(:ruby_api_response) do
    [
      {
        "cycle" => "3.3",
        "releaseDate" => "2023-12-25",
        "eol" => "2027-03-31",
        "latest" => "3.3.0",
        "latestReleaseDate" => "2023-12-25"
      },
      {
        "cycle" => "3.2",
        "releaseDate" => "2022-12-25",
        "eol" => "2026-03-31",
        "latest" => "3.2.2",
        "latestReleaseDate" => "2023-03-30"
      }
    ]
  end

  let(:rails_api_response) do
    [
      {
        "cycle" => "7.1",
        "releaseDate" => "2023-10-05",
        "eol" => "2026-10-05",
        "latest" => "7.1.0",
        "support" => "2025-10-05"
      },
      {
        "cycle" => "7.0",
        "releaseDate" => "2021-12-15",
        "eol" => "2025-06-01",
        "latest" => "7.0.8",
        "support" => "2024-06-01"
      }
    ]
  end

  before do
    FileUtils.mkdir_p(cache_dir)
  end

  after do
    FileUtils.rm_rf(cache_dir)
  end

  describe "#fetch" do
    context "when fetching Ruby EOL data" do
      before do
        allow(fetcher).to receive(:fetch_from_api).with("ruby").and_return(ruby_api_response)
      end

      it "returns parsed EOL data" do
        result = fetcher.fetch("ruby")
        expect(result).to be_an(Array)
        expect(result.first["cycle"]).to eq("3.3")
        expect(result.first["eol"]).to eq("2027-03-31")
      end

      it "caches the data locally" do
        fetcher.fetch("ruby")
        cache_file = File.join(cache_dir, "ruby.json")
        expect(File.exist?(cache_file)).to be true

        cached_data = JSON.parse(File.read(cache_file))
        expect(cached_data.first["cycle"]).to eq("3.3")
      end
    end

    context "when fetching Rails EOL data" do
      before do
        allow(fetcher).to receive(:fetch_from_api).with("rails").and_return(rails_api_response)
      end

      it "returns parsed EOL data" do
        result = fetcher.fetch("rails")
        expect(result).to be_an(Array)
        expect(result.first["cycle"]).to eq("7.1")
      end
    end

    context "when cache exists and is fresh" do
      before do
        cache_file = File.join(cache_dir, "ruby.json")
        File.write(cache_file, ruby_api_response.to_json)
        File.utime(Time.now, Time.now, cache_file)
      end

      it "returns cached data without hitting API" do
        expect(fetcher).not_to receive(:fetch_from_api)
        result = fetcher.fetch("ruby")
        expect(result.first["cycle"]).to eq("3.3")
      end
    end

    context "when cache is stale" do
      before do
        cache_file = File.join(cache_dir, "ruby.json")
        File.write(cache_file, ruby_api_response.to_json)
        # Set file time to 2 days ago
        File.utime(Time.now - (2 * 24 * 60 * 60), Time.now - (2 * 24 * 60 * 60), cache_file)

        allow(fetcher).to receive(:fetch_from_api).with("ruby").and_return(ruby_api_response)
      end

      it "fetches fresh data from API" do
        expect(fetcher).to receive(:fetch_from_api).with("ruby")
        fetcher.fetch("ruby")
      end
    end

    context "when API request fails" do
      before do
        allow(fetcher).to receive(:fetch_from_api).with("ruby").and_raise(SocketError)
      end

      it "returns nil" do
        expect(fetcher.fetch("ruby")).to be_nil
      end

      context "and cache exists" do
        before do
          cache_file = File.join(cache_dir, "ruby.json")
          File.write(cache_file, ruby_api_response.to_json)
          # Make cache stale
          File.utime(Time.now - (2 * 24 * 60 * 60), Time.now - (2 * 24 * 60 * 60), cache_file)
        end

        it "falls back to stale cache" do
          result = fetcher.fetch("ruby")
          expect(result.first["cycle"]).to eq("3.3")
        end
      end
    end
  end

  describe "#eol_date_for" do
    before do
      allow(fetcher).to receive(:fetch_from_api).with("ruby").and_return(ruby_api_response)
      fetcher.fetch("ruby")
    end

    it "returns EOL date for exact version match" do
      date = fetcher.eol_date_for("ruby", "3.3.0")
      expect(date).to eq("2027-03-31")
    end

    it "returns EOL date for major.minor version" do
      date = fetcher.eol_date_for("ruby", "3.2.0")
      expect(date).to eq("2026-03-31")
    end

    it "returns nil for unknown version" do
      date = fetcher.eol_date_for("ruby", "2.7.0")
      expect(date).to be_nil
    end

    it "matches version by major.minor only" do
      date = fetcher.eol_date_for("ruby", "3.2.999")
      expect(date).to eq("2026-03-31")
    end
  end
end
