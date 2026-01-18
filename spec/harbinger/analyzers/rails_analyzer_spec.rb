# frozen_string_literal: true

require "spec_helper"
require "harbinger/analyzers/rails_analyzer"

RSpec.describe Harbinger::Analyzers::RailsAnalyzer do
  let(:project_path) { "/tmp/test_project" }
  subject(:analyzer) { described_class.new(project_path) }

  describe "#detect" do
    context "when Gemfile.lock exists with rails gem" do
      let(:gemfile_lock_content) do
        <<~LOCKFILE
          GEM
            remote: https://rubygems.org/
            specs:
              actioncable (7.1.0)
                actionpack (= 7.1.0)
              actionpack (7.1.0)
                rack (~> 2.0)
              rails (7.1.0)
                actioncable (= 7.1.0)
                actionpack (= 7.1.0)
              rack (2.2.8)

          PLATFORMS
            ruby

          DEPENDENCIES
            rails (~> 7.1)

          BUNDLED WITH
             2.4.10
        LOCKFILE
      end

      before do
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(gemfile_lock_content)
      end

      it "returns the Rails version from Gemfile.lock" do
        expect(analyzer.detect).to eq("7.1.0")
      end
    end

    context "when Gemfile.lock has Rails with patch version" do
      let(:gemfile_lock_content) do
        <<~LOCKFILE
          GEM
            specs:
              rails (7.0.8.1)
                actioncable (= 7.0.8.1)

          DEPENDENCIES
            rails
        LOCKFILE
      end

      before do
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(gemfile_lock_content)
      end

      it "returns the full version including patch" do
        expect(analyzer.detect).to eq("7.0.8.1")
      end
    end

    context "when Gemfile.lock exists but rails is not a dependency" do
      let(:gemfile_lock_content) do
        <<~LOCKFILE
          GEM
            remote: https://rubygems.org/
            specs:
              sinatra (3.0.5)
                rack (~> 2.2)

          DEPENDENCIES
            sinatra

          BUNDLED WITH
             2.4.10
        LOCKFILE
      end

      before do
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(gemfile_lock_content)
      end

      it "returns nil" do
        expect(analyzer.detect).to be_nil
      end
    end

    context "when Gemfile.lock does not exist" do
      before do
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(false)
      end

      it "returns nil" do
        expect(analyzer.detect).to be_nil
      end
    end

    context "when file read fails" do
      before do
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_raise(Errno::ENOENT)
      end

      it "returns nil" do
        expect(analyzer.detect).to be_nil
      end
    end

    context "when rails appears in different formats" do
      it "handles indented rails gem" do
        lockfile = "  specs:\n    rails (6.1.7.3)\n      actionpack"
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(lockfile)

        expect(analyzer.detect).to eq("6.1.7.3")
      end

      it "handles rails with multiple spaces" do
        lockfile = "  rails    (5.2.8.1)"
        allow(File).to receive(:exist?).with("#{project_path}/Gemfile.lock").and_return(true)
        allow(File).to receive(:read).with("#{project_path}/Gemfile.lock").and_return(lockfile)

        expect(analyzer.detect).to eq("5.2.8.1")
      end
    end
  end
end
