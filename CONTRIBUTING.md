# Contributing to leechtop_downloader

Bug reports and pull requests are welcome on GitHub at <https://github.com/VitaliiLazebnyi/leechtop-downloader>.

## Getting started

The repository develops on the Ruby in `.ruby-version` (4.0.9); Ruby 3.3 and newer are supported.

```bash
bundle install
git config core.hooksPath .githooks   # run the fast gates before every commit (LT-REQ-008)
```

## Before opening a pull request

Run every check of CI locally, with the same settings and the same pinned tools:

```bash
script/check
```

It runs each of the following with every Ruby warning enabled (`RUBYOPT=-w -W:deprecated -W:performance`), and
fails on any finding and on any warning in the output of any of them:

- `bundle exec rake`, which runs, in order:
  - `rake spec`: RSpec with 100% line **and** branch coverage; any Ruby warning, pending, skipped or focused
    example fails the run; no example reaches the network (WebMock);
  - `rake legacy_suite`: the original spec suite of `main` (before the hardening pass) passes against the current
    `lib/` (`script/legacy_suite.rb` lists the few documented adaptations);
  - `rake rubocop`: RuboCop with **every** cop enabled (`EnabledByDefault`), including those of rubocop-md,
    -packaging, -performance, -rake, -rspec, -sorbet, -thread_safety and -yard; `.rubocop.yml` gives the reason
    for each of the few cops that cannot apply; no todo file;
  - `rake suppressions`: no inline suppression anywhere (`script/forbidden_suppressions.sh`, see below);
  - `rake typecheck`: the committed gem RBIs match the bundle (`tapioca gem --verify`), then `srb tc` reports no
    errors; `lib/` and `exe/` are `# typed: strict`, the scripts `# typed: true`;
  - `rake yard`: YARD reports 100% documented, without warnings;
  - `rake reek`, `rake flay`, `rake flog`, `rake debride`: no code smell (default Reek configuration), no
    structural duplication (default Flay mass), no method with a Flog score above 20, and no method without a
    caller, in `lib/`, `exe/`, `script/` and the `Rakefile`;
  - `rake audit`: bundler-audit: no dependency with a known vulnerability;
- `rake outdated`: every gem at its newest release, except the holds in `script/outdated_holds.yml`;
- `gem build --strict` and the executable itself;
- `rake mutant`: mutation testing on Ruby 3.3.13; every mutation must be killed (`.mutant.yml`);
- `script/lint.sh`: the linters and scanners of every other file type, each at its strictest setting, installed
  at pinned versions by `script/install_tools.sh` (`tools/`):
  - [actionlint](https://github.com/rhysd/actionlint), with ShellCheck on every `run:` block, and
    [zizmor](https://github.com/zizmorcore/zizmor) with its pedantic persona and online audits: the workflows;
  - [ShellCheck](https://www.shellcheck.net/) with every optional check and
    [shfmt](https://github.com/mvdan/sh): every shell script;
  - [yamllint](https://github.com/adrienverge/yamllint) with every rule, strict (`.yamllint.yml`);
  - [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) with every rule
    (`.markdownlint-cli2.yaml`);
  - [Taplo](https://taplo.tamasfe.dev/): the TOML files;
  - [typos](https://github.com/crate-ci/typos): the spelling of every tracked file (`_typos.toml`);
  - [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker): every tracked file
    against `.editorconfig`;
  - [gitleaks](https://github.com/gitleaks/gitleaks): the full git history, for committed secrets.

CI runs the same checks, the RSpec suite on every supported Ruby, and the GitHub services: CodeQL, the OpenSSF
Scorecard of this repository, and dependency review on pull requests. Dependency review fails on a vulnerable (of any
severity) or denied dependency, and `script/scorecard_check` fails on any added dependency whose OpenSSF Scorecard is
below 3, unless `.github/dependency-review.yml` allows that exact package version at that score with a written
reason (the action itself can only lower its threshold for every package at once). Every job runs behind
[Harden-Runner](https://github.com/step-security/harden-runner), which blocks any network access outside the
endpoints its workflow lists.

Mutation testing is the one gate that does not run on the Ruby of `.ruby-version`: the newest Mutant (0.17.1)
and Unparser (0.9.0) load the `parser` gem's `parser/current`, which only has grammars up to Ruby 3.3 and warns on
any newer Ruby. `script/check` runs it on Ruby 3.3.13 (through [mise](https://mise.jdx.dev/) when another Ruby is
active); `rake outdated` fails once that hold is no longer needed (see `script/outdated_holds.yml`). While
iterating, run one subject at a time, e.g. `bundle exec mutant run 'LeechtopDownloader::Filename*'`.

With `-w`, the newest releases of a few development tools warn about their own code while they load.
`script/upstream_warnings.rb` (loaded through `RUBYOPT`) drops exactly those warnings, each matched by gem version,
file and message; every other warning is printed and fails the build.

## Rules

- **No inline suppressions.** Nothing may silence a linter, scanner, type checker, warning or test in place: no
  `rubocop:disable`, `:nocov:`, `:reek:`, `mutant:disable`, `:nodoc:`, `gitleaks:allow`, `nosec`,
  `markdownlint-disable`, `yamllint disable`, `T.unsafe`/`T.cast`/`T.bind`/`T.untyped` in `lib/`,
  `$VERBOSE = nil`, `skip`/`pending`/`focus`, `WebMock.allow_net_connect!`, and so on. Fix the cause. A rule
  that cannot apply to a file is configured narrowly in the tool's configuration file, with the reason written
  next to it.
- **No warnings.** Every Ruby command runs with all warnings enabled, and the specs fail on any warning. Every
  workflow ends with a "Warning gate (*workflow*)" job (`script/warning_gate.sh`) that fails the run when the log
  of any job contains a warning or a deprecation notice; `script/check` applies the same check to its own output.
- **Behavior is specified.** Every behavioral fix needs a regression spec, and every surviving mutant needs a test that
  kills it (or, when the mutation cannot change observable behavior, simpler code).
- **Dependencies are current.** `rake outdated` fails for any gem, RubyGems or Bundler that is not at its newest
  release, unless `script/outdated_holds.yml` names it together with the upstream constraint that blocks the update.
  `Gemfile.lock` is committed so that CI checks exactly the bundle the RBIs were generated from; the gem RBIs in
  `sorbet/rbi/gems/` are generated: after `bundle update` run `bundle exec tapioca gem` instead of editing them.
- Record requirements in `REQUIREMENTS.md`, defects in `BUGS.md` and user-visible changes in `CHANGELOG.md`.
