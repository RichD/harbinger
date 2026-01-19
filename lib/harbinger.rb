# frozen_string_literal: true

require_relative "harbinger/version"
require_relative "harbinger/cli"
require_relative "harbinger/analyzers/ruby_detector"
require_relative "harbinger/analyzers/rails_analyzer"
require_relative "harbinger/analyzers/database_detector"
require_relative "harbinger/analyzers/postgres_detector"
require_relative "harbinger/analyzers/mysql_detector"
require_relative "harbinger/eol_fetcher"

module Harbinger
  class Error < StandardError; end
end
