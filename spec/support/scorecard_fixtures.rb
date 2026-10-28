# typed: false
# frozen_string_literal: true

require 'json'

# Dependency changes and Scorecard API stubs for the specs of script/scorecard_check.rb.
module ScorecardFixtures
  # A dependency change as dependency-review-action reports it.
  def dependency_change(name, version, repository: "https://github.com/example/#{name}", type: 'added',
                        ecosystem: 'rubygems')
    { change_type: type, ecosystem: ecosystem, name: name, version: version, source_repository_url: repository }
  end

  # The problems ScorecardCheck finds in +changes+ (it prints a line per added dependency).
  def check_problems(*changes)
    result = nil
    expect { result = ScorecardCheck.problems(changes, config, lockfile) }.to output(//).to_stdout
    result
  end

  # Stubs a GET request that answers with +body+ as JSON (or with HTTP 404 when +body+ is nil).
  def stub_json(url, body)
    stub = stub_request(:get, url)
    body ? stub.to_return(status: 200, body: JSON.generate(body)) : stub.to_return(status: 404)
  end

  # Stubs the Scorecard of a repository.
  def stub_scorecard(repository, score)
    stub_request(:get, "https://api.securityscorecards.dev/projects/#{repository}")
      .to_return(status: 200, body: JSON.generate(score: score))
  end
end
