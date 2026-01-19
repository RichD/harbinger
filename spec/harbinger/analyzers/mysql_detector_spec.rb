# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/database_detector"
require "harbinger/analyzers/mysql_detector"
require "fileutils"
require "tmpdir"

RSpec.describe Harbinger::Analyzers::MysqlDetector do
  let(:temp_dir) { Dir.mktmpdir }
  let(:detector) { described_class.new(temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#adapter_name" do
    it "returns array with mysql2 and trilogy" do
      expect(detector.send(:adapter_name)).to eq(["mysql2", "trilogy"])
    end
  end

  describe "#detect" do
    context "when MySQL is not in database.yml" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.postgresql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end

    context "when mysql2 adapter is in database.yml" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      context "when mysql command is available" do
        before do
          allow(detector).to receive(:execute_command).with("mysql --version")
            .and_return("mysql  Ver 8.0.33 for Linux on x86_64 (MySQL Community Server - GPL)")
        end

        it "returns version from mysql command" do
          expect(detector.detect).to eq("8.0.33")
        end
      end

      context "when mysql command fails but mysqld works" do
        before do
          allow(detector).to receive(:execute_command).with("mysql --version")
            .and_return(nil)
          allow(detector).to receive(:execute_command).with("mysqld --version")
            .and_return("mysqld  Ver 8.0.33 for Linux on x86_64 (MySQL Community Server - GPL)")
        end

        it "returns version from mysqld command" do
          expect(detector.detect).to eq("8.0.33")
        end
      end

      context "when both commands fail" do
        before do
          allow(detector).to receive(:execute_command).with("mysql --version")
            .and_return(nil)
          allow(detector).to receive(:execute_command).with("mysqld --version")
            .and_return(nil)
          FileUtils.cp(
            "spec/fixtures/Gemfile.lock.with_mysql2",
            File.join(temp_dir, "Gemfile.lock")
          )
        end

        it "falls back to mysql2 gem version" do
          expect(detector.detect).to eq("0.5.5 (mysql2 gem)")
        end
      end
    end

    context "when trilogy adapter is in database.yml" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.trilogy",
          File.join(temp_dir, "config", "database.yml")
        )
      end

      context "when mysql commands fail" do
        before do
          allow(detector).to receive(:execute_command).with("mysql --version")
            .and_return(nil)
          allow(detector).to receive(:execute_command).with("mysqld --version")
            .and_return(nil)
          FileUtils.cp(
            "spec/fixtures/Gemfile.lock.with_trilogy",
            File.join(temp_dir, "Gemfile.lock")
          )
        end

        it "falls back to trilogy gem version" do
          expect(detector.detect).to eq("2.7.0 (trilogy gem)")
        end
      end
    end
  end

  describe "#detect_from_shell" do
    it "parses standard MySQL version from mysql command" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return("mysql  Ver 8.0.33 for Linux on x86_64 (MySQL Community Server - GPL)")
      expect(detector.send(:detect_from_shell)).to eq("8.0.33")
    end

    it "parses MySQL version from mysqld command" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return(nil)
      allow(detector).to receive(:execute_command).with("mysqld --version")
        .and_return("mysqld  Ver 8.0.33 for Linux on x86_64")
      expect(detector.send(:detect_from_shell)).to eq("8.0.33")
    end

    it "parses MariaDB version" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return("mysql  Ver 15.1 Distrib 10.11.2-MariaDB")
      expect(detector.send(:detect_from_shell)).to eq("10.11.2")
    end

    it "parses MySQL 5.7 version" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return("mysql  Ver 5.7.42 for osx10.17 on x86_64")
      expect(detector.send(:detect_from_shell)).to eq("5.7.42")
    end

    it "parses Homebrew MySQL version" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return("mysql  Ver 8.1.0 for macos13.3 on arm64 (Homebrew)")
      expect(detector.send(:detect_from_shell)).to eq("8.1.0")
    end

    it "returns nil when both commands fail" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return(nil)
      allow(detector).to receive(:execute_command).with("mysqld --version")
        .and_return(nil)
      expect(detector.send(:detect_from_shell)).to be_nil
    end

    it "returns nil when version cannot be parsed" do
      allow(detector).to receive(:execute_command).with("mysql --version")
        .and_return("some unexpected output")
      allow(detector).to receive(:execute_command).with("mysqld --version")
        .and_return(nil)
      expect(detector.send(:detect_from_shell)).to be_nil
    end
  end

  describe "#detect_from_gemfile_lock" do
    context "when Gemfile.lock exists with mysql2 gem" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_mysql2",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns mysql2 gem version with label" do
        expect(detector.send(:detect_from_gemfile_lock)).to eq("0.5.5 (mysql2 gem)")
      end
    end

    context "when Gemfile.lock exists with trilogy gem" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.trilogy",
          File.join(temp_dir, "config", "database.yml")
        )
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_trilogy",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns trilogy gem version with label" do
        expect(detector.send(:detect_from_gemfile_lock)).to eq("2.7.0 (trilogy gem)")
      end
    end

    context "when Gemfile.lock does not exist" do
      it "returns nil" do
        expect(detector.send(:detect_from_gemfile_lock)).to be_nil
      end
    end

    context "when Gemfile.lock exists without MySQL gems" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        FileUtils.cp(
          "spec/fixtures/database.yml.mysql",
          File.join(temp_dir, "config", "database.yml")
        )
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_pg",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "returns nil" do
        expect(detector.send(:detect_from_gemfile_lock)).to be_nil
      end
    end
  end

  describe "remote database detection" do
    context "when host is remote (AWS RDS, etc.)" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            adapter: mysql2
            host: mydb.abc123.us-east-1.rds.amazonaws.com
            database: myapp_production
        YAML
        FileUtils.cp(
          "spec/fixtures/Gemfile.lock.with_mysql2",
          File.join(temp_dir, "Gemfile.lock")
        )
      end

      it "skips shell command and uses gem version" do
        expect(detector).not_to receive(:execute_command)
        expect(detector.detect).to eq("0.5.5 (mysql2 gem)")
      end
    end

    context "when host is localhost" do
      before do
        FileUtils.mkdir_p(File.join(temp_dir, "config"))
        File.write(File.join(temp_dir, "config", "database.yml"), <<~YAML)
          production:
            adapter: mysql2
            host: localhost
            database: myapp_production
        YAML
        allow(detector).to receive(:execute_command).with("mysql --version")
          .and_return("mysql  Ver 8.0.33 for Linux")
      end

      it "uses shell command" do
        expect(detector.detect).to eq("8.0.33")
      end
    end
  end
end
