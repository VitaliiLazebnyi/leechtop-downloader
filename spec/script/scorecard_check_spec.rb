# typed: false
# frozen_string_literal: true

require 'spec_helper'
require_relative '../../script/scorecard_check'

RSpec.describe ScorecardCheck do
  include ScorecardFixtures

  let(:config) do
    { 'warn-on-openssf-scorecard-level': 3, 'scorecard-allowances': { 'rubygems/ruby-progressbar': allowance } }
  end
  let(:allowance) { { version: '1.13.0', score: 2.8, reason: 'RuboCop requires it.' } }
  let(:lockfile) { "GEM\n  specs:\n    ruby-progressbar (1.13.0)\n    rake (13.4.2)\n" }
  let(:progressbar) { 'github.com/example/ruby-progressbar' }
  let(:deps_dev_rake) { 'https://api.deps.dev/v3/systems/rubygems/packages/rake/versions/13.4.2' }

  describe '.problems' do
    it 'passes an added dependency whose score reaches the threshold' do
      stub_scorecard('github.com/example/rake', 3)
      expect(check_problems(dependency_change('rake', '13.4.2'))).to eq([])
    end

    it 'fails an added dependency below the threshold that no allowance covers' do
      stub_scorecard('github.com/example/crack', 2.9)
      expect(check_problems(dependency_change('crack', '1.0.1')))
        .to eq(['rubygems/crack 1.0.1 has an OpenSSF Scorecard of 2.9, below 3, ' \
                'and no allowance in .github/dependency-review.yml covers it'])
    end

    it 'passes a dependency below the threshold that an allowance covers at that version and score' do
      stub_scorecard(progressbar, 2.8)
      expect(check_problems(dependency_change('ruby-progressbar', '1.13.0'))).to eq([])
    end

    it 'fails an allowed dependency whose score dropped below the allowed score' do
      stub_scorecard(progressbar, 2.7)
      expect(check_problems(dependency_change('ruby-progressbar', '1.13.0')))
        .to contain_exactly(/ruby-progressbar 1.13.0 .* 2.7/)
    end

    it 'fails an allowed dependency at another version than the allowed one' do
      stub_scorecard(progressbar, 2.8)
      expect(check_problems(dependency_change('ruby-progressbar', '1.14.0'))).to contain_exactly(/1.14.0/)
    end

    it 'ignores removed dependencies' do
      expect(check_problems(dependency_change('crack', '1.0.1', type: 'removed'))).to eq([])
    end

    it 'skips a dependency without a published Scorecard, like dependency-review-action' do
      stub_json('https://api.securityscorecards.dev/projects/github.com/example/rbi', nil)
      expect(check_problems(dependency_change('rbi', '0.5.0'))).to eq([])
    end

    it 'prints the score of every added dependency' do
      stub_scorecard('github.com/example/rake', 6.4)
      expect { described_class.problems([dependency_change('rake', '13.4.2')], config, lockfile) }
        .to output("rubygems/rake 13.4.2: OpenSSF Scorecard 6.4\n").to_stdout
    end

    it 'prints the dependencies that have no Scorecard' do
      stub_json('https://api.securityscorecards.dev/projects/github.com/example/rbi', nil)
      expect { described_class.problems([dependency_change('rbi', '0.5.0')], config, lockfile) }
        .to output("rubygems/rbi 0.5.0: OpenSSF Scorecard not published\n").to_stdout
    end

    it 'fails an allowance without a reason' do
      allowance[:reason] = ' '
      expect(check_problems).to eq(['the allowance for rubygems/ruby-progressbar gives no reason'])
    end

    it 'fails an allowance for a gem version that Gemfile.lock no longer has' do
      allowance[:version] = '1.12.0'
      expect(check_problems)
        .to eq(['the allowance for rubygems/ruby-progressbar 1.12.0 is stale: Gemfile.lock no longer has that version'])
    end

    it 'keeps an allowance for another ecosystem without checking Gemfile.lock' do
      config[:'scorecard-allowances'] = { 'actions/example/action': allowance }
      expect(check_problems).to eq([])
    end

    it 'treats a configuration without allowances as allowing nothing' do
      config.delete(:'scorecard-allowances')
      stub_scorecard(progressbar, 2.8)
      expect(check_problems(dependency_change('ruby-progressbar', '1.13.0'))).to contain_exactly(/no allowance/)
    end
  end

  describe '.main' do
    it 'checks the dependency changes against the repository configuration and returns 0 when they pass',
       :aggregate_failures do
      stub_scorecard('github.com/example/rake', 6.4)
      status = nil
      expect { status = described_class.main(JSON.generate([dependency_change('rake', '13.4.2')])) }
        .to output(/rake/).to_stdout
      expect(status).to eq(0)
    end

    it 'passes a pull request that changes no dependency (the action then sets no output)' do
      expect(described_class.main('')).to eq(0)
    end

    it 'prints every problem as an error and returns 1', :aggregate_failures do
      stub_scorecard('github.com/example/crack', 1)
      status = nil
      expect { status = described_class.main(JSON.generate([dependency_change('crack', '1.0.1')])) }
        .to output(%r{^::error::rubygems/crack 1.0.1 has an OpenSSF Scorecard of 1}).to_stdout
      expect(status).to eq(1)
    end
  end

  describe '.repository' do
    it 'uses the source repository GitHub knows, without the protocol' do
      expect(described_class.repository(dependency_change('rake', '13.4.2'))).to eq('github.com/example/rake')
    end

    it 'derives the repository of a GitHub Action from its name, without a sub-action path' do
      action = dependency_change('actions/checkout/sub', 'v7', repository: nil, ecosystem: 'actions')
      expect(described_class.repository(action)).to eq('github.com/actions/checkout')
    end

    it 'asks deps.dev for the project of a package version GitHub has no repository for' do
      stub_json(deps_dev_rake, relatedProjects: [{ projectKey: { id: 'github.com/ruby/rake' } }])
      expect(described_class.repository(dependency_change('rake', '13.4.2', repository: '')))
        .to eq('github.com/ruby/rake')
    end

    it 'encodes the version, so that a gemspec requirement such as "~> 0.9" is looked up (and not found) safely' do
      stub_json('https://api.deps.dev/v3/systems/rubygems/packages/rake/versions/~%3E%200.9', nil)
      expect(described_class.repository(dependency_change('rake', '~> 0.9', repository: nil))).to be_nil
    end

    it 'finds no repository when deps.dev knows none' do
      stub_json(deps_dev_rake, nil)
      expect(described_class.repository(dependency_change('rake', '13.4.2', repository: nil))).to be_nil
    end

    it 'finds no repository when deps.dev links the version to no project' do
      stub_json(deps_dev_rake, relatedProjects: [])
      expect(described_class.repository(dependency_change('rake', '13.4.2', repository: nil))).to be_nil
    end
  end

  describe '.score' do
    it 'has no score without a repository' do
      expect(described_class.score(nil)).to be_nil
    end

    it 'has no score when the Scorecard has none' do
      stub_json('https://api.securityscorecards.dev/projects/github.com/a/b', {})
      expect(described_class.score('github.com/a/b')).to be_nil
    end
  end
end
