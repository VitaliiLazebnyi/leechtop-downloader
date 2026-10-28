# typed: false
# frozen_string_literal: true

# Must come first: it has to see the warnings emitted while lib/ and spec/ are loaded.
require_relative 'support/warning_guard'

require 'simplecov'

# Mutation runs execute the suite thousands of times against deliberately broken code; the coverage gate
# is meaningless (and noisy) there.
SimpleCov.start do
  next if defined?(Mutant)

  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
  SimpleCov.skip(%r{/spec/})
end

require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'

require 'leechtop_downloader'

# Evaluate every Sorbet signature now: an example that stubs a method whose signature was never evaluated
# would otherwise make sorbet-runtime drop that signature (with a warning).
T::Utils.run_all_sig_blocks

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |support_file| require support_file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.fail_if_no_examples = true

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Mutation testing maps examples to the code they verify by the constant a spec describes. The
  # end-to-end examples exercise every class, so every example is offered to every subject.
  config.define_derived_metadata do |metadata|
    metadata[:mutant_expression] = 'LeechtopDownloader*'
  end

  config.include LeechtopPages

  # No example may reach the network, and every example starts in an empty working directory (downloads
  # land in the current directory by default) with its own temporary directory for the application lock.
  config.around do |example|
    original_tmpdir = ENV.fetch('TMPDIR', nil)
    Dir.mktmpdir('leechtop-spec') do |directory|
      ENV['TMPDIR'] = FileUtils.mkdir_p(File.join(directory, 'tmp')).first
      Dir.chdir(FileUtils.mkdir_p(File.join(directory, 'work')).first) { example.run }
    ensure
      ENV['TMPDIR'] = original_tmpdir
    end
  end

  # Ruby warnings are failures, never noise.
  config.before(:suite) do
    load_time_warnings = WarningGuard.drain
    raise "Ruby warnings while loading:\n#{load_time_warnings.join}" unless load_time_warnings.empty?
  end

  config.after do
    warnings = WarningGuard.drain
    raise "Ruby warnings emitted by this example:\n#{warnings.join}" unless warnings.empty?
  end

  # Pending and skipped examples hide missing behavior: the suite must not contain any.
  config.after(:suite) do
    unfinished = RSpec.world.all_examples.select do |example|
      example.execution_result.status == :pending || example.skipped? || example.pending?
    end
    unless unfinished.empty?
      raise "Pending or skipped examples are not allowed:\n#{unfinished.map(&:full_description).join("\n")}"
    end
  end
end
