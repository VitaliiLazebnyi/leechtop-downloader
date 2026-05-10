# typed: false
# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

require "webmock/rspec"
require "sorbet-runtime"

# Need to load the application here, but let's wait until it's created.
require_relative "../lib/leechtop_downloader"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.before do
    # Ensure UTC timezone is enforced in tests
    ENV["TZ"] = "UTC"
    # Isolate tmpdir so that running downloader instances do not lock out tests
    ENV["TMPDIR"] = File.expand_path("tmp", __dir__)
    FileUtils.mkdir_p(ENV.fetch("TMPDIR", nil))
  end

  config.after(:suite) do
    FileUtils.rm_rf(ENV.fetch("TMPDIR", nil)) if ENV["TMPDIR"]&.end_with?("spec/tmp")
  end
end
