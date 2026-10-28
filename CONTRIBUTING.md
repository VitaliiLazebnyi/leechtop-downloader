# Contributing to leechtop_downloader

Bug reports and pull requests are welcome on GitHub at <https://github.com/VitaliiLazebnyi/leechtop-downloader>.

## Getting started

The repository develops on the Ruby in `.ruby-version` (4.0.9); Ruby 3.3 and newer are supported.

```bash
bundle install
git config core.hooksPath .githooks   # run the fast gates before every commit (LT-REQ-008)
```

## Before opening a pull request

Run the verification suite. Every gate is enforced in CI and fails the build:

```bash
bundle exec rake
```

That runs, in order:

| Task | Gate |
| --- | --- |
| `rake spec` | RSpec with `--warnings`; 100% line **and** branch coverage; any Ruby warning, pending, skipped or focused example fails the run; no example reaches the network (WebMock) |
| `rake legacy_suite` | the original spec suite of `main` (before the hardening pass) passes against the current `lib/` (`script/legacy_suite.rb` lists the few documented adaptations) |
| `rake rubocop` | RuboCop with rubocop-md, -performance, -rake, -rspec, -sorbet and -thread_safety (`.rubocop.yml`); no todo file |
| `rake suppressions` | no inline suppression anywhere (`script/forbidden_suppressions.sh`, see below) |
| `rake typecheck` | the committed gem RBIs match the bundle (`tapioca gem --verify`), then `srb tc` reports no errors; `lib/` and `exe/` are `# typed: strict` |
| `rake yard` | YARD reports 100% documented, without warnings |
| `rake reek` / `rake flay` | no code smell (default Reek configuration) and no structural duplication (default Flay mass) |
| `rake audit` | bundler-audit: no dependency with a known vulnerability |

Not part of the default task, but also enforced in CI:

```bash
bundle exec rake mutant     # mutation testing on Ruby 3.3.13; every mutation must be killed (.mutant.yml)
bundle exec rake outdated   # every gem at its newest release, except the holds in script/outdated_holds.yml
gem build leechtop_downloader.gemspec
```

The other CI checks run tools that are not gems. The pre-commit hook runs each one that is installed:

| Tool | Checks |
| --- | --- |
| [actionlint](https://github.com/rhysd/actionlint) and [zizmor](https://github.com/zizmorcore/zizmor) | the GitHub Actions workflows |
| [ShellCheck](https://www.shellcheck.net/) | `script/*.sh` and `.githooks/pre-commit` |
| [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) | every Markdown file (`.markdownlint-cli2.yaml`) |
| [typos](https://github.com/crate-ci/typos) | the spelling of every tracked file (`_typos.toml`) |
| [gitleaks](https://github.com/gitleaks/gitleaks) | the full git history for committed secrets |

CI also runs CodeQL, dependency review and the OpenSSF Scorecard.

Mutant parses the code with the `parser` gem, whose newest release only has a grammar for Ruby 3.3; run it on
Ruby 3.3.13 (CI does). While iterating, run one subject at a time, e.g.
`bundle exec mutant run 'LeechtopDownloader::Filename*'`.

## Rules

- **No inline suppressions.** Nothing may silence a linter, scanner, type checker, warning or test in place: no
  `rubocop:disable`, `:nocov:`, `:reek:`, `mutant:disable`, `:nodoc:`, `gitleaks:allow`, `nosec`, `markdownlint-disable`,
  `T.unsafe`/`T.cast`/`T.bind`/`T.untyped` in `lib/`, `$VERBOSE = nil`, `skip`/`pending`/`focus`,
  `WebMock.allow_net_connect!`, and so on. Fix the cause. A rule that cannot apply to a file is configured narrowly in
  the tool's configuration file, with the reason written next to it.
- **No warnings.** The specs run with Ruby warnings enabled and fail on any warning. Every workflow ends with a
  "Warning gate" job (`script/warning_gate.sh`) that fails the run when the log of any job contains a warning or a
  deprecation notice.
- **Behavior is specified.** Every behavioral fix needs a regression spec, and every surviving mutant needs a test that
  kills it (or, when the mutation cannot change observable behavior, simpler code).
- **Dependencies are current.** `rake outdated` fails for any gem that is not at its newest release, unless
  `script/outdated_holds.yml` names it together with the upstream constraint that blocks the update. The gem RBIs in
  `sorbet/rbi/gems/` are generated: after a dependency update run `bundle exec tapioca gem` instead of editing them.
- Record requirements in `REQUIREMENTS.md`, defects in `BUGS.md` and user-visible changes in `CHANGELOG.md`.
