# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/database_detector"
require "fileutils"
require "tmpdir"

RSpec.describe Harbinger::Analyzers::DatabaseDetector do
  # Create a concrete test class since DatabaseDetector is abstract
  let(:test_detector_class) do
    Class.new(described_class) do
      def adapter_name
        "postgresql"
      end

      def detect_from_shell
        "15.3"
      end

      def detect_from_gemfile_lock
        "1.5.4 (gem version)"
      end
    end
  end

  let(:temp_dir) { Dir.mktmpdir }
  let(:detector) { test_detector_class.new(temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    it "stores the project path" do
      expect(detector.project_path).to eq(temp_dir)
    end
  end

  describe "#detect" do
    context "when database is not detected in database.yml" do
      it "returns nil" do
        # No database.yml file
        expect(detector.detect).to be_nil
      end
    end

    context "when database is detected" do
      before do
        # Create config directory and copy postgresql database.yml
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns version from shell command first" do
        expect(detector.detect).to eq("15.3")
      end

      context "when shell command fails" do
        let(:test_detector_class) do
          Class.new(described_class) do
            def adapter_name
              "postgresql"
            end

            def detect_from_shell
              nil
            end

            def detect_from_gemfile_lock
              "1.5.4 (gem version)"
            end
          end
        end

        it "falls back to gemfile lock" do
          expect(detector.detect).to eq("1.5.4 (gem version)")
        end
      end
    end
  end

  describe "#database_detected?" do
    context "when database.yml does not exist" do
      it "returns false" do
        expect(detector.database_detected?).to be false
      end
    end

    context "when database.yml exists with matching adapter" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns true" do
        expect(detector.database_detected?).to be true
      end
    end

    context "when database.yml exists with different adapter" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns false" do
        expect(detector.database_detected?).to be false
      end
    end

    context "when database.yml is malformed" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.malformed",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns false" do
        expect(detector.database_detected?).to be false
      end
    end

    context "when adapter_name returns an array" do
      let(:test_detector_class) do
        Class.new(described_class) do
          def adapter_name
            ["mysql2", "trilogy"]
          end

          def detect_from_shell
            "8.0.33"
          end

          def detect_from_gemfile_lock
            "0.5.5 (gem version)"
          end
        end
      end

      it "matches mysql2" do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
        expect(detector.database_detected?).to be true
      end

      it "matches trilogy" do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.trilogy",
          File.join(temp_dir, "config", "database.yml")
        )
        expect(detector.database_detected?).to be true
      end
    end

    context "when database.yml has multi-database configuration (Rails 6+)" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.multi",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "detects adapter from primary database" do
        expect(detector.database_detected?).to be true
      end
    end
  end

  describe "#parse_database_yml" do
    context "when database.yml exists and is valid" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns parsed YAML hash" do
        config = detector.send(:parse_database_yml)
        expect(config).to be_a(Hash)
        expect(config["production"]).to be_a(Hash)
        expect(config["production"]["adapter"]).to eq("postgresql")
      end
    end

    context "when database.yml does not exist" do
      it "returns nil" do
        expect(detector.send(:parse_database_yml)).to be_nil
      end
    end

    context "when database.yml is malformed" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.malformed",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns nil" do
        expect(detector.send(:parse_database_yml)).to be_nil
      end
    end
  end

  describe "#parse_gemfile_lock" do
    context "when Gemfile.lock exists" do
      before do
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns the file content" do
        content = detector.send(:parse_gemfile_lock)
        expect(content).to be_a(String)
        expect(content).to include("pg (1.5.4)")
      end
    end

    context "when Gemfile.lock does not exist" do
      it "returns nil" do
        expect(detector.send(:parse_gemfile_lock)).to be_nil
      end
    end
  end

  describe "#extract_gem_version" do
    let(:gemfile_lock_content) do
      File.read("spec/fixtures/Gemfile.lock.with_pg")
    end

    it "extracts pg gem version" do
      version = detector.send(:extract_gem_version, gemfile_lock_content, "pg")
      expect(version).to eq("1.5.4")
    end

    it "extracts rails gem version" do
      version = detector.send(:extract_gem_version, gemfile_lock_content, "rails")
      expect(version).to eq("7.1.2")
    end

    it "returns nil for missing gem" do
      version = detector.send(:extract_gem_version, gemfile_lock_content, "nonexistent")
      expect(version).to be_nil
    end

    it "returns nil when content is nil" do
      version = detector.send(:extract_gem_version, nil, "pg")
      expect(version).to be_nil
    end
  end

  describe "#execute_command" do
    it "executes a successful command" do
      result = detector.send(:execute_command, "echo 'test'")
      expect(result).to eq("test")
    end

    it "returns nil for a failed command" do
      result = detector.send(:execute_command, "nonexistent_command_xyz")
      expect(result).to be_nil
    end
  end

  describe "abstract methods" do
    let(:abstract_detector) { described_class.new(temp_dir) }

    it "raises NotImplementedError for adapter_name" do
      expect { abstract_detector.send(:adapter_name) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for detect_from_shell" do
      expect { abstract_detector.send(:detect_from_shell) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for detect_from_gemfile_lock" do
      expect { abstract_detector.send(:detect_from_gemfile_lock) }.to raise_error(NotImplementedError)
    end
  end
end
