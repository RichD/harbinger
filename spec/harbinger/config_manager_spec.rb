# frozen_string_literal: true

require "spec_helper"
require "harbinger/config_manager"
require "fileutils"
require "yaml"

RSpec.describe Harbinger::ConfigManager do
  let(:test_config_dir) { "/tmp/harbinger_test_config" }
  let(:config_file) { File.join(test_config_dir, "config.yml") }
  subject(:manager) { described_class.new(config_dir: test_config_dir) }

  before do
    FileUtils.mkdir_p(test_config_dir)
  end

  after do
    FileUtils.rm_rf(test_config_dir)
  end

  describe "#save_project" do
    it "creates a new project entry" do
      manager.save_project(
        name: "my-app",
        path: "/Users/test/Projects/my-app",
        versions: { ruby: "3.2.0", rails: "7.0.8" }
      )

      config = YAML.load_file(config_file)
      expect(config["projects"]["my-app"]).to include(
        "path" => "/Users/test/Projects/my-app",
        "ruby" => "3.2.0",
        "rails" => "7.0.8"
      )
      expect(config["projects"]["my-app"]["last_scanned"]).to be_a(String)
      expect(config["projects"]["my-app"]["last_scanned"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)  # ISO8601 format
    end

    it "updates an existing project entry" do
      manager.save_project(name: "my-app", path: "/path", versions: { ruby: "3.1.0", rails: "7.0.0" })
      manager.save_project(name: "my-app", path: "/path", versions: { ruby: "3.2.0", rails: "7.1.0" })

      config = YAML.load_file(config_file)
      expect(config["projects"]["my-app"]["ruby"]).to eq("3.2.0")
      expect(config["projects"]["my-app"]["rails"]).to eq("7.1.0")
    end

    it "handles nil values gracefully" do
      manager.save_project(name: "my-app", path: "/path", versions: { ruby: "3.2.0", rails: nil })

      config = YAML.load_file(config_file)
      expect(config["projects"]["my-app"]["ruby"]).to eq("3.2.0")
      expect(config["projects"]["my-app"]["rails"]).to be_nil
    end

    it "creates config file if it doesn't exist" do
      expect(File.exist?(config_file)).to be false

      manager.save_project(name: "my-app", path: "/path", versions: { ruby: "3.2.0" })

      expect(File.exist?(config_file)).to be true
    end

    it "preserves existing projects when adding new ones" do
      manager.save_project(name: "app1", path: "/path1", versions: { ruby: "3.1.0" })
      manager.save_project(name: "app2", path: "/path2", versions: { ruby: "3.2.0" })

      projects = manager.list_projects
      expect(projects.keys).to contain_exactly("app1", "app2")
    end
  end

  describe "#list_projects" do
    context "when config file exists with projects" do
      before do
        manager.save_project(name: "app1", path: "/path1", versions: { ruby: "3.1.0", rails: "7.0.0" })
        manager.save_project(name: "app2", path: "/path2", versions: { ruby: "3.2.0", rails: nil })
      end

      it "returns all projects" do
        projects = manager.list_projects
        expect(projects.keys).to contain_exactly("app1", "app2")
      end

      it "returns project details" do
        projects = manager.list_projects
        expect(projects["app1"]).to include(
          "path" => "/path1",
          "ruby" => "3.1.0",
          "rails" => "7.0.0"
        )
      end
    end

    context "when config file doesn't exist" do
      it "returns empty hash" do
        expect(manager.list_projects).to eq({})
      end
    end

    context "when config file is empty" do
      before do
        File.write(config_file, "")
      end

      it "returns empty hash" do
        expect(manager.list_projects).to eq({})
      end
    end

    context "when config file is corrupt" do
      before do
        File.write(config_file, "invalid: yaml: content: [")
      end

      it "returns empty hash and doesn't crash" do
        expect(manager.list_projects).to eq({})
      end
    end
  end

  describe "#get_project" do
    before do
      manager.save_project(name: "my-app", path: "/path", versions: { ruby: "3.2.0", rails: "7.0.8" })
    end

    it "returns project by name" do
      project = manager.get_project("my-app")
      expect(project).to include(
        "path" => "/path",
        "ruby" => "3.2.0",
        "rails" => "7.0.8"
      )
    end

    it "returns nil for non-existent project" do
      expect(manager.get_project("non-existent")).to be_nil
    end
  end

  describe "#remove_project" do
    before do
      manager.save_project(name: "app1", path: "/path1", versions: { ruby: "3.1.0" })
      manager.save_project(name: "app2", path: "/path2", versions: { ruby: "3.2.0" })
    end

    it "removes the specified project" do
      manager.remove_project("app1")

      projects = manager.list_projects
      expect(projects.keys).to eq(["app2"])
    end

    it "doesn't error when removing non-existent project" do
      expect { manager.remove_project("non-existent") }.not_to raise_error
    end
  end

  describe "#project_count" do
    it "returns 0 when no projects" do
      expect(manager.project_count).to eq(0)
    end

    it "returns correct count" do
      manager.save_project(name: "app1", path: "/path1", versions: { ruby: "3.1.0" })
      manager.save_project(name: "app2", path: "/path2", versions: { ruby: "3.2.0" })

      expect(manager.project_count).to eq(2)
    end
  end
end
