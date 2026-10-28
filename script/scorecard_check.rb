# typed: false
# frozen_string_literal: true

# Checks the OpenSSF Scorecard of every dependency a pull request adds, like dependency-review-action does,
# but with explicit per-package allowances. The action can only lower its threshold for every package at once,
# so its own Scorecard report is off (.github/dependency-review.yml) and this check runs on its
# `dependency-changes` output instead.
#
# A dependency whose score is below the threshold fails the check, unless .github/dependency-review.yml allows
# that exact package version at that score (or higher), with a written reason. An allowance for a gem that is
# not in Gemfile.lock at that version fails the check as well, so that none outlives its reason.
#
# Run by script/scorecard_check: DEPENDENCY_CHANGES='<JSON>' script/scorecard_check

require 'json'
require 'net/http'
require 'uri'
require 'yaml'

# The Scorecard check (see the comment at the top of this file).
module ScorecardCheck
  ROOT = File.expand_path('..', __dir__)
  CONFIG = File.join(ROOT, '.github', 'dependency-review.yml')
  SCORECARD_API = 'https://api.securityscorecards.dev/projects/'
  DEPS_DEV_API = 'https://api.deps.dev/v3/systems/'
  public_constant :ROOT, :CONFIG, :SCORECARD_API, :DEPS_DEV_API

  # One added dependency and its score.
  Result = Struct.new(:package, :version, :score, keyword_init: true)
  public_constant :Result

  module_function

  # Runs the check on the `dependency-changes` JSON of dependency-review-action and prints the problems as errors.
  # @param changes_json [String] empty when the pull request changes no dependency (the action then sets no output)
  # @return [Integer] the exit status: 0 when the check passes
  def main(changes_json)
    found = problems(changes_json.empty? ? [] : JSON.parse(changes_json, symbolize_names: true),
                     YAML.safe_load_file(CONFIG, symbolize_names: true),
                     File.read(File.join(ROOT, 'Gemfile.lock')))
    found.each { |problem| puts "::error::#{problem}" }
    found.empty? ? 0 : 1
  end

  # Runs the check and returns the problems it found (an empty list when it passes).
  # @param changes [Array<Hash>] the `dependency-changes` output of dependency-review-action
  # @param config [Hash] the parsed .github/dependency-review.yml
  # @param lockfile [String] the content of Gemfile.lock
  # @return [Array<String>]
  def problems(changes, config, lockfile)
    allowances = config.fetch(:'scorecard-allowances', {})
    threshold = config.fetch(:'warn-on-openssf-scorecard-level')
    results = changes.filter_map { |change| result(change) if change.fetch(:change_type) == 'added' }
    results.each { |entry| puts describe(entry) }
    results.filter_map { |entry| below_threshold(entry, threshold, allowances) } +
      stale_allowances(allowances, lockfile)
  end

  # The package, version and score of an added dependency.
  # @param change [Hash] one dependency change
  # @return [Result]
  def result(change)
    package = "#{change.fetch(:ecosystem)}/#{change.fetch(:name)}"
    version = change.fetch(:version)
    Result.new(package: package, version: version, score: score(repository(change)))
  end

  # The source repository of a dependency, the way dependency-review-action finds it: the URL GitHub knows,
  # the owner/repository of a GitHub Action, or else the project deps.dev links to that version.
  # @param change [Hash] one dependency change
  # @return [String, nil] e.g. "github.com/jfelchner/ruby-progressbar"
  def repository(change)
    url = change[:source_repository_url].to_s.delete_prefix('https://')
    return url unless url.empty?

    ecosystem, name, version = change.values_at(:ecosystem, :name, :version)
    return "github.com/#{name.split('/').first(2).join('/')}" if ecosystem == 'actions'

    # Gemspec entries name a requirement (e.g. "~> 0.9") instead of a version: encoded, deps.dev knows no such version.
    get_json("#{DEPS_DEV_API}#{ecosystem}/packages/#{URI.encode_uri_component(name)}/versions/" \
             "#{URI.encode_uri_component(version)}")
      &.dig(:relatedProjects, 0, :projectKey, :id)
  end

  # The overall OpenSSF Scorecard score of a repository.
  # @param repository [String, nil]
  # @return [Float, nil] nil when the repository has no Scorecard
  def score(repository)
    repository && get_json("#{SCORECARD_API}#{repository}")&.fetch(:score, nil)
  end

  # The parsed JSON body of a GET request, or nil when it does not answer with HTTP 200.
  # @param url [String]
  # @return [Hash, nil]
  def get_json(url)
    response = Net::HTTP.get_response(URI(url))
    JSON.parse(response.body, symbolize_names: true) if response.is_a?(Net::HTTPOK)
  end

  # The line printed for an added dependency.
  # @param entry [Result]
  # @return [String]
  def describe(entry)
    "#{entry.package} #{entry.version}: OpenSSF Scorecard #{entry.score || 'not published'}"
  end

  # The problem of a dependency below the threshold that no allowance covers.
  # @param entry [Result]
  # @param threshold [Numeric]
  # @param allowances [Hash]
  # @return [String, nil]
  def below_threshold(entry, threshold, allowances)
    score = entry.score
    return if score.nil? || score >= threshold

    allowance = allowances[entry.package.to_sym]
    return if allowance && allowance[:version] == entry.version && score >= allowance[:score]

    "#{entry.package} #{entry.version} has an OpenSSF Scorecard of #{score}, below #{threshold}, " \
      'and no allowance in .github/dependency-review.yml covers it'
  end

  # The problems of allowances that are incomplete or name a gem version Gemfile.lock no longer has.
  # @param allowances [Hash]
  # @param lockfile [String]
  # @return [Array<String>]
  def stale_allowances(allowances, lockfile)
    allowances.filter_map do |package, allowance|
      ecosystem, name = package.to_s.split('/', 2)
      version = allowance[:version]
      if allowance[:reason].to_s.strip.empty?
        "the allowance for #{package} gives no reason"
      elsif ecosystem == 'rubygems' && !lockfile.include?("\n    #{name} (#{version})")
        "the allowance for #{package} #{version} is stale: Gemfile.lock no longer has that version"
      end
    end
  end
end
