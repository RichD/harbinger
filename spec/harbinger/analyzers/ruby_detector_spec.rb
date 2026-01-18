# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/ruby_detector"

RSpec.describe Harbinger::Analyzers::RubyDetector do
  let(:project_path) { "/tmp/test_project" }
  subject(:detector) { described_class.new(project_path) }

  describe "#detect" do
    context "when .ruby-version file exists" do
      it "returns the version from .ruby-version" do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/.ruby-version").and_return("3.2.0\n")

        expect(detector.detect).to eq("3.2.0")
      end

      it "strips whitespace from version" do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/.ruby-version").and_return("  3.1.4  \n")

        expect(detector.detect).to eq("3.1.4")
      end

      it "handles ruby- prefix in version" do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/.ruby-version").and_return("ruby-3.3.0")

        expect(detector.detect).to eq("3.3.0")
      end
    end

    context "when Gemfile exists with ruby declaration" do
      let(:gemfile_content) do
        <<~GEMFILE
          source "https://rubygems.org"

          ruby "3.2.2"

          gem "rails", "~> 7.0"
        GEMFILE
      end

      before do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(false)
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile").and_return(gemfile_content)
      end

      it "returns the version from Gemfile" do
        expect(detector.detect).to eq("3.2.2")
      end
    end

    context "when Gemfile.lock exists with RUBY VERSION" do
      let(:gemfile_lock_content) do
        <<~LOCKFILE
          GEM
            remote: https://rubygems.org/
            specs:
              rails (7.0.8)

          PLATFORMS
            ruby

          RUBY VERSION
             ruby 3.1.4p223

          BUNDLED WITH
             2.4.10
        LOCKFILE
      end

      before do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(false)
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile").and_return(false)
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(gemfile_lock_content)
      end

      it "returns the version from Gemfile.lock" do
        expect(detector.detect).to eq("3.1.4")
      end

      it "handles version without patch level" do
        lockfile_simple = gemfile_lock_content.gsub("ruby 3.1.4p223", "ruby 3.1.4")
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(lockfile_simple)

        expect(detector.detect).to eq("3.1.4")
      end
    end

    context "when no Ruby version files exist" do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end

    context "when file read fails" do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/.ruby-version").and_raise(Errno::ENOENT)
      end

      it "returns nil" do
        expect(detector.detect).to be_nil
      end
    end

    context "priority order" do
      it "prefers .ruby-version over Gemfile" do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/.ruby-version").and_return("3.3.0")
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile").and_return('ruby "3.2.0"')

        expect(detector.detect).to eq("3.3.0")
      end

      it "prefers Gemfile over Gemfile.lock" do
        allow(File).to receive(:exist?).with("#{project_path}/.ruby-version").and_return(false)
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile").and_return('ruby "3.2.0"')
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return("RUBY VERSION\n   ruby 3.1.0")

        expect(detector.detect).to eq("3.2.0")
      end
    end
  end
end
