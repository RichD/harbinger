# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/go_detector"
require "fileutils"
require "tmpdir"

RSpec.describe Harbinger::Analyzers::GoDetector do
  let(:temp_dir) { Dir.mktmpdir }
  let(:detector) { described_class.new(temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#detect" do
    context "when go.mod exists" do
      it "detects Go version from go.mod" do
        File.write(File.join(temp_dir, "go.mod"), <<~GOMOD)
          module github.com/example/project

          go 1.21

          require (
            github.com/foo/bar v1.0.0
          )
        GOMOD

        expect(detector.detect).to eq("1.21")
      end

      it "detects Go version with patch number" do
        File.write(File.join(temp_dir, "go.mod"), <<~GOMOD)
          module github.com/example/project

          go 1.21.5

          require (
            github.com/foo/bar v1.0.0
          )
        GOMOD

        expect(detector.detect).to eq("1.21.5")
      end

      it "handles go.mod with comments" do
        File.write(File.join(temp_dir, "go.mod"), <<~GOMOD)
          module github.com/example/project

          // This project uses Go 1.21
          go 1.21.0

          require (
            github.com/foo/bar v1.0.0
          )
        GOMOD

        expect(detector.detect).to eq("1.21.0")
      end
    end

    context "when go.work exists" do
      it "detects Go version from go.work" do
        File.write(File.join(temp_dir, "go.work"), <<~GOWORK)
          go 1.21

          use (
            ./module1
            ./module2
          )
        GOWORK

        expect(detector.detect).to eq("1.21")
      end

      it "prefers go.mod over go.work" do
        File.write(File.join(temp_dir, "go.mod"), "module example\n\ngo 1.22\n")
        File.write(File.join(temp_dir, "go.work"), "go 1.21\n")

        expect(detector.detect).to eq("1.22")
      end
    end

    context "when .go-version exists" do
      it "detects Go version from .go-version" do
        File.write(File.join(temp_dir, ".go-version"), "1.21.0\n")

        expect(detector.detect).to eq("1.21.0")
      end

      it "strips whitespace from .go-version" do
        File.write(File.join(temp_dir, ".go-version"), "  1.21.0  \n")

        expect(detector.detect).to eq("1.21.0")
      end

      it "prefers go.mod over .go-version" do
        File.write(File.join(temp_dir, "go.mod"), "module example\n\ngo 1.22\n")
        File.write(File.join(temp_dir, ".go-version"), "1.21.0\n")

        expect(detector.detect).to eq("1.22")
      end
    end

    context "when docker-compose.yml exists" do
      it "detects Go version from golang image" do
        File.write(File.join(temp_dir, "docker-compose.yml"), <<~YAML)
          version: '3'
          services:
            app:
              image: golang:1.21
              volumes:
                - .:/app
        YAML

        expect(detector.detect).to eq("1.21")
      end

      it "detects Go version from golang image with patch" do
        File.write(File.join(temp_dir, "docker-compose.yml"), <<~YAML)
          version: '3'
          services:
            app:
              image: golang:1.21.5
        YAML

        expect(detector.detect).to eq("1.21.5")
      end

      it "normalizes alpine variants" do
        File.write(File.join(temp_dir, "docker-compose.yml"), <<~YAML)
          version: '3'
          services:
            app:
              image: golang:1.21-alpine
        YAML

        expect(detector.detect).to eq("1.21")
      end

      it "normalizes rc versions" do
        File.write(File.join(temp_dir, "docker-compose.yml"), <<~YAML)
          version: '3'
          services:
            app:
              image: golang:1.22-rc1
        YAML

        expect(detector.detect).to eq("1.22")
      end

      it "prefers go.mod over docker-compose.yml" do
        File.write(File.join(temp_dir, "go.mod"), "module example\n\ngo 1.22\n")
        File.write(File.join(temp_dir, "docker-compose.yml"), "services:\n  app:\n    image: golang:1.21\n")

        expect(detector.detect).to eq("1.22")
      end
    end

    context "when using shell fallback" do
      it "does not use shell when no Go project files exist" do
        allow(detector).to receive(:`).and_return("go version go1.21.0 darwin/amd64")

        expect(detector.detect).to be_nil
        expect(detector).not_to have_received(:`)
      end

      it "uses shell fallback when go.mod exists" do
        File.write(File.join(temp_dir, "go.mod"), "module example\n\n")
        allow(detector).to receive(:`).with("go version 2>/dev/null").and_return("go version go1.21.0 darwin/amd64")

        expect(detector.detect).to eq("1.21.0")
      end

      it "handles shell command failure gracefully" do
        File.write(File.join(temp_dir, "go.mod"), "module example\n\n")
        allow(detector).to receive(:`).and_raise(StandardError.new("command not found"))

        expect(detector.detect).to be_nil
      end
    end

    context "when no version is found" do
      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end
  end

  describe "#go_detected?" do
    it "returns true when go.mod exists" do
      File.write(File.join(temp_dir, "go.mod"), "module example\n")

      expect(detector.go_detected?).to be true
    end

    it "returns true when go.work exists" do
      File.write(File.join(temp_dir, "go.work"), "go 1.21\n")

      expect(detector.go_detected?).to be true
    end

    it "returns true when .go-version exists" do
      File.write(File.join(temp_dir, ".go-version"), "1.21.0\n")

      expect(detector.go_detected?).to be true
    end

    it "returns false when no Go files exist" do
      expect(detector.go_detected?).to be false
    end
  end
end
