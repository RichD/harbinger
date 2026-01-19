# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/database_detector"
require "harbinger/analyzers/postgres_detector"
require "fileutils"
require "tmpdir"

RSpec.describe Harbinger::Analyzers::PostgresDetector do
  let(:temp_dir) { Dir.mktmpdir }
  let(:detector) { described_class.new(temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#adapter_name" do
    it "returns postgresql" do
      expect(detector.send(:adapter_name)).to eq("postgresql")
    end
  end

  describe "#detect" do
    context "when PostgreSQL is not in database.yml" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end

    context "when PostgreSQL is in database.yml" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      context "when psql command is available" do
        before do
          allow(detector).to receive(:execute_command).with("psql --version")
            .and_return("psql (PostgreSQL) 15.3")
        end

        it "returns version from psql command" do
          expect(detector.detect).to eq("15.3")
        end
      end

      context "when psql command fails" do
        before do
          allow(detector).to receive(:execute_command).with("psql --version")
            .and_return(nil)
          FileUtils.cp(
            "spec/fixtures/Gemfile.lock.with_pg",
            File.join(temp_dir, "Gemfile.lock")
          )
        end

        it "falls back to pg gem version" do
          expect(detector.detect).to eq("1.5.4 (pg gem)")
        end
      end

      context "when neither psql nor pg gem is available" do
        before do
          allow(detector).to receive(:execute_command).with("psql --version")
            .and_return(nil)
        end

        it "returns nil" do
          expect(detector.detect).to be_nil
        end
      end
    end
  end

  describe "#detect_from_shell" do
    it "parses standard PostgreSQL version format" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return("psql (PostgreSQL) 15.3")
      expect(detector.send(:detect_from_shell)).to eq("15.3")
    end

    it "parses PostgreSQL version with distribution info" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return("psql (PostgreSQL) 14.9 (Ubuntu 14.9-1.pgdg22.04+1)")
      expect(detector.send(:detect_from_shell)).to eq("14.9")
    end

    it "parses PostgreSQL version with additional text" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return("psql (PostgreSQL) 16.1 (Homebrew)")
      expect(detector.send(:detect_from_shell)).to eq("16.1")
    end

    it "handles single digit major version" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return("psql (PostgreSQL) 9.6")
      expect(detector.send(:detect_from_shell)).to eq("9.6")
    end

    it "returns nil when command fails" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return(nil)
      expect(detector.send(:detect_from_shell)).to be_nil
    end

    it "returns nil when version cannot be parsed" do
      allow(detector).to receive(:execute_command).with("psql --version")
        .and_return("some unexpected output")
      expect(detector.send(:detect_from_shell)).to be_nil
    end
  end

  describe "#detect_from_gemfile_lock" do
    context "when Gemfile.lock exists with pg gem" do
      before do
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns pg gem version with label" do
        expect(detector.send(:detect_from_gemfile_lock)).to eq("1.5.4 (pg gem)")
      end
    end

    context "when Gemfile.lock does not exist" do
      it "returns nil" do
        expect(detector.send(:detect_from_gemfile_lock)).to be_nil
      end
    end

    context "when Gemfile.lock exists without pg gem" do
      before do
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_mysql2",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns nil" do
        expect(detector.send(:detect_from_gemfile_lock)).to be_nil
      end
    end
  end

  describe "integration with real database.yml formats" do
    context "with multi-database configuration" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.multi",
          File.join(temp_dir, "config", "database.yml")
        )
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
        allow(detector).to receive(:execute_command).with("psql --version")
          .and_return(nil)
      end

      it "detects PostgreSQL from primary database" do
        expect(detector.detect).to eq("1.5.4 (pg gem)")
      end
    end
  end

  describe "remote database detection" do
    context "when host is not specified (Unix socket/localhost)" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
        allow(detector).to receive(:execute_command).with("psql --version")
          .and_return("psql (PostgreSQL) 15.3")
      end

      it "uses shell command" do
        expect(detector.detect).to eq("15.3")
      end
    end

    context "when host is localhost" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            adapter: postgresql
            host: localhost
            database: myapp_production
        YAML
        allow(detector).to receive(:execute_command).with("psql --version")
          .and_return("psql (PostgreSQL) 15.3")
      end

      it "uses shell command" do
        expect(detector.detect).to eq("15.3")
      end
    end

    context "when host is 127.0.0.1" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            adapter: postgresql
            host: 127.0.0.1
            database: myapp_production
        YAML
        allow(detector).to receive(:execute_command).with("psql --version")
          .and_return("psql (PostgreSQL) 15.3")
      end

      it "uses shell command" do
        expect(detector.detect).to eq("15.3")
      end
    end

    context "when host is remote (AWS RDS, etc.)" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            adapter: postgresql
            host: mydb.abc123.us-east-1.rds.amazonaws.com
            database: myapp_production
        YAML
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "skips shell command and uses gem version" do
        # Should NOT call execute_command
        expect(detector).not_to receive(:execute_command)
        expect(detector.detect).to eq("1.5.4 (pg gem)")
      end
    end

    context "when host is remote in multi-database config" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            primary:
              adapter: postgresql
              host: db.example.com
              database: myapp_production
        YAML
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "skips shell command for remote multi-database config" do
        expect(detector).not_to receive(:execute_command)
        expect(detector.detect).to eq("1.5.4 (pg gem)")
      end
    end
  end
end
