#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

# Fails when a dependency is not at its newest release and script/outdated_holds.yml does not list it, or when a
# listed hold is no longer needed. Checks the gems of the bundle (`bundle outdated`), RubyGems and Bundler
# themselves, and the jobs that are held on an older Ruby.

require 'bundler'
require 'open3'
require 'yaml'

root = File.expand_path('..', __dir__)
holds = YAML.safe_load_file(File.join(root, 'script', 'outdated_holds.yml'))
problems = []

# Gems of the bundle.
output, = Open3.capture2e('bundle', 'outdated', '--parseable', chdir: root)
pattern = /^(\S+) \(newest ([^,\s]+), installed ([^,)\s]+)/
outdated = output.scan(pattern).to_h { |name, newest, installed| [name, [newest, installed]] }
gem_holds = holds.fetch('gems')
outdated.each do |name, (newest, installed)|
  puts "outdated: #{name} #{installed} -> #{newest}#{' (on hold)' if gem_holds.key?(name)}"
  problems << "NOT ON THE HOLD LIST: #{name} #{installed} -> #{newest}" unless gem_holds.dig(name, 'newest') == newest
end
(gem_holds.keys - outdated.keys).each { |name| problems << "STALE HOLD (no longer outdated): #{name}" }

# RubyGems and Bundler.
{ 'rubygems-update': Gem::VERSION, bundler: Bundler::VERSION }.each do |name, installed|
  newest = Gem.latest_version_for(name.to_s)
  next problems << "could not look up the newest #{name}" unless newest

  puts "#{name}: #{installed} (newest #{newest})"
  problems << "OUTDATED: #{name} #{installed} -> #{newest}" if Gem::Version.new(installed) < newest
end

# Jobs held on an older Ruby: still needed while a listed file requires parser/current, and pinned in the workflow.
holds.fetch('ruby').each do |job, hold|
  still_blocked = hold.fetch('blocked_by').any? do |entry|
    gem_name, file = entry.split(':').then { |(gem_part, path)| [gem_part.split.first, path.strip] }
    spec = Gem::Specification.find_by_name(gem_name)
    File.read(File.join(spec.full_gem_path, file)).include?('parser/current')
  end
  problems << "STALE RUBY HOLD (no longer needed): #{job}" unless still_blocked
  workflow = File.read(File.join(root, hold.fetch('workflow')))
  unless workflow.include?(%(ruby-version: "#{hold.fetch('ruby')}"))
    problems << "#{hold.fetch('workflow')} does not run #{job} on the held Ruby #{hold.fetch('ruby')}"
  end
  puts "held: #{job} runs on Ruby #{hold.fetch('ruby')}"
end

problems.each { |problem| warn problem }
exit(problems.empty? ? 0 : 1)
