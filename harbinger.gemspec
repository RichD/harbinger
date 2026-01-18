# frozen_string_literal: true

require_relative "lib/harbinger/version"

Gem::Specification.new do |spec|
  spec.name = "harbinger"
  spec.version = Harbinger::VERSION
  spec.authors = ["Rich Dabrowski"]
  spec.email = ["engineering@richd.net"]

  spec.summary = "Track End-of-Life dates for your tech stack and stay ahead of deprecations"
  spec.description = "Harbinger monitors EOL dates for Ruby, Rails, PostgreSQL and other technologies in your stack. Auto-detects versions from your projects and alerts you before support ends."
  spec.homepage = "https://stackharbinger.com"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/RichD/harbinger"
  spec.metadata["changelog_uri"] = "https://github.com/RichD/harbinger/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "colorize", "~> 1.1"
  spec.add_dependency "httparty", "~> 0.21"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
