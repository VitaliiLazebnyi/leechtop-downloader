# frozen_string_literal: true

# Copyright (c) 2026 Vitalii Lazebnyi

require 'bundler/gem_tasks'
require 'open3'
require 'rspec/core/rake_task'
require 'tmpdir'

# Output of `yard stats` when every API object is documented.
FULLY_DOCUMENTED = '100.00% documented'
# The Ruby code that the smell, duplication, complexity and dead-code checks analyze: the gem and its tooling.
ANALYZED = %w[lib exe script script/scorecard_check Rakefile].freeze
# Flog score above which a single method counts as too complex and must be split up.
FLOG_METHOD_THRESHOLD = 20
# Methods debride cannot see a caller for, each with the caller it cannot see.
DEBRIDE_ALLOWED = { exit_on_failure?: 'Thor calls it to choose the exit status of a failed command' }.freeze

# Helpers of the tasks below.
module Tasks
  # Runs a report command, prints its output (standard output and error), and returns it; fails when the command
  # fails.
  # @param command [Array<String>]
  # @return [String]
  def self.report(*command)
    output, status = Open3.capture2e(*command)
    puts(output)
    abort("#{command.join(' ')} failed (#{status})") unless status.success?
    output
  end
end

RSpec::Core::RakeTask.new(:spec)

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Fail on inline suppressions of any linter, scanner, type checker, warning or test'
task :suppressions do
  sh 'script/forbidden_suppressions.sh'
end

desc 'Verify that the committed gem RBIs match the bundle (Tapioca), then run the Sorbet type checker'
task :typecheck do
  sh 'bundle exec tapioca gem --verify'
  sh 'bundle exec srb tc'
end

desc 'Fail unless every API object is documented'
task :yard do
  output = Tasks.report('bundle', 'exec', 'yard', 'stats', '--list-undoc')
  abort 'YARD: undocumented API objects found' unless output.include?(FULLY_DOCUMENTED)
  abort 'YARD: warnings found' if output.match?(/\[warn\]|warning/i)
end

desc 'Fail on any code smell (default Reek configuration, no exclusions)'
task :reek do
  sh('bundle', 'exec', 'reek', *ANALYZED)
end

desc 'Fail on any structural duplication (default Flay mass)'
task :flay do
  output = Tasks.report('bundle', 'exec', 'flay', *ANALYZED)
  abort 'Flay: duplicated code found' unless output.start_with?('Total score (lower is better) = 0')
end

desc "Fail on any method with a Flog score above #{FLOG_METHOD_THRESHOLD}"
task :flog do
  scores = Tasks.report(
    'bundle',
    'exec',
    'flog',
    '--all',
    '--methods-only',
    *ANALYZED
  ).scan(/^ *(\d+\.\d+): (\S+) +\S+:\d+/)
  complex = scores.filter_map { |score, name| name if Float(score) > FLOG_METHOD_THRESHOLD }
  abort "Flog: methods scoring above #{FLOG_METHOD_THRESHOLD}: #{complex.join(', ')}" unless complex.empty?
end

desc 'Fail on any method nothing calls (Debride; see DEBRIDE_ALLOWED)'
task :debride do
  Dir.mktmpdir('debride') do |directory|
    allowed = File.join(directory, 'allowed.txt')
    File.write(allowed, DEBRIDE_ALLOWED.keys.join("\n"))
    output = Tasks.report('bundle', 'exec', 'debride', '--whitelist', allowed, *ANALYZED, 'leechtop_downloader.gemspec')
    abort 'Debride: methods without a caller found' unless output.include?('Total suspect LOC: 0')
  end
end

desc 'Audit gem dependencies for known vulnerabilities'
task :audit do
  sh 'bundle exec bundler-audit check --update'
end

desc 'Fail on outdated gems that are not on the documented hold list'
task :outdated do
  ruby 'script/outdated.rb'
end

desc 'Run mutation testing; every mutation must be killed (see .mutant.yml)'
task :mutant do
  sh 'bundle exec mutant run'
end

desc 'Run the original (pre-hardening) spec suite against the current lib/'
task :legacy_suite do
  ruby 'script/legacy_suite.rb'
end

task default: %i[spec legacy_suite rubocop suppressions typecheck yard reek flay flog debride audit]
