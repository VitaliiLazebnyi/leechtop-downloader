#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

# Runs the ORIGINAL spec files of this gem (as they were on `main` before the hardening pass) against the
# current `lib/`, to prove that the public behavior did not change. Every example of the original suite must
# pass; there is no list of tolerated failures. The only edits made to the original files are listed below,
# each with its reason; the expectations themselves are unchanged.

require 'fileutils'
require 'json'
require 'open3'

# The last commit of `main` before the pass; its spec directory is the original suite.
ORIGINAL_COMMIT = '33edfa900a273c72cd9423c433203c9fe70bc91f'
# How many examples that suite has; fewer would mean part of it silently stopped running.
ORIGINAL_EXAMPLES = 43

root = File.expand_path('..', __dir__)
work = File.join(root, 'tmp', 'legacy')
FileUtils.rm_rf(work)
FileUtils.mkdir_p(work)

archive, status = Open3.capture2('git', 'archive', ORIGINAL_COMMIT, 'spec', chdir: root, binmode: true)
abort "git archive #{ORIGINAL_COMMIT} failed (is the full history fetched?)" unless status.success?
_, status = Open3.capture2('tar', '-x', '-C', work, stdin_data: archive, binmode: true)
abort 'tar failed' unless status.success?
# The original spec_helper loads the code with `require_relative '../lib/leechtop_downloader'`. A link (not a
# copy) lets Ruby recognize the files Bundler already loaded from the gemspec (version.rb), which a copy would
# load a second time, redefining their constants.
File.symlink(File.join(root, 'lib'), File.join(work, 'lib'))

# Applies +edits+ (pairs of original text and replacement) to a file of the original suite; every original
# text must still be present, so that an edit can never silently stop applying.
def adapt(path, edits)
  text = File.read(path)
  edits.each do |before, after|
    abort "#{path} no longer contains:\n#{before}" unless text.include?(before)

    text = text.gsub(before, after)
  end
  File.write(path, text)
end

# 1. SimpleCov: the original spec_helper calls `add_filter`, which the current SimpleCov renamed to `skip`
#    (the old name prints a DEPRECATION notice on every run), and enforces a 100% coverage floor on the
#    files the original suite loads. Coverage is enforced by this release's own suite, so here the floor is
#    dropped and only the rename is applied.
adapt(File.join(work, 'spec', 'spec_helper.rb'), [
        %w[add_filter skip],
        ['minimum_coverage line: 100, branch: 100', 'minimum_coverage line: 0, branch: 0']
      ])

cli_spec = File.join(work, 'spec', 'leechtop_downloader', 'cli_spec.rb')
adapt(cli_spec, [
        # 2. The mojibake repair moved from the CLI instance (where it was a public method only because a
        #    helper module was mixed in) to LeechtopDownloader::Filename; the inputs and expected outputs of
        #    its four examples are unchanged.
        ['cli.fix_encoding(', 'LeechtopDownloader::Filename.repair_encoding('],
        # 3. The links-file example stubs two internals that changed: the private CLI#process_url (the CLI
        #    now hands every URL to a Downloader built from its options) and File.readlines(path,
        #    chomp: true) (the file is now read as UTF-8 explicitly, replacing the global Encoding settings
        #    of the executable, which Ruby warns about). The example still checks that exactly the two
        #    non-empty lines are processed, with the default options.
        ['allow(File).to receive(:readlines).with(file_path, chomp: true)',
         'allow(File).to receive(:readlines).with(file_path, chomp: true, encoding: Encoding::UTF_8)'],
        ['allow(cli).to receive(:process_url)', <<~RUBY.strip],
          downloader = LeechtopDownloader::Downloader.new(skip_existing: true, destination: '.')
                  allow(LeechtopDownloader::Downloader).to receive(:new).with(skip_existing: true, destination: '.')
                    .and_return(downloader)
                  allow(downloader).to receive(:process)
        RUBY
        ["expect(cli).to have_received(:process_url).with(first_url, skip_existing: true, destination: '.')",
         'expect(downloader).to have_received(:process).with(first_url)'],
        ["expect(cli).to have_received(:process_url).with(second_url, skip_existing: true, destination: '.')",
         'expect(downloader).to have_received(:process).with(second_url)'],
        ['expect(cli).to have_received(:process_url).exactly(2).times',
         'expect(downloader).to have_received(:process).exactly(2).times']
      ])

# 4. Like this release's spec_helper, every Sorbet signature is evaluated once the code is loaded: an example
#    that stubs a method whose signature was never evaluated makes sorbet-runtime drop it with a warning.
File.write(File.join(work, 'spec', 'evaluate_signatures.rb'), "T::Utils.run_all_sig_blocks\n")

result = File.join(work, 'result.json')
ENV['BUNDLE_GEMFILE'] = File.join(root, 'Gemfile')
# The per-example JSON result is judged, not the exit code.
system('bundle', 'exec', 'rspec', '--options', File::NULL, '-I', 'spec',
       '-r', 'spec_helper', '-r', 'evaluate_signatures', '--format', 'json', '--out', result,
       *Dir.glob('spec/**/*_spec.rb', base: work),
       chdir: work, out: File::NULL)

report = JSON.parse(File.read(result))
failed = report.fetch('examples').filter_map do |example|
  "#{example.fetch('full_description')}: #{example.dig('exception', 'message')}" if example.fetch('status') == 'failed'
end
count = report.dig('summary', 'example_count')
puts "Original suite: #{count} examples, #{failed.size} failing"
failed.each { |name| warn "FAILURE: #{name}" }
errors = report.dig('summary', 'errors_outside_of_examples_count') || 0
warn "#{errors} error(s) outside of examples (the suite did not load)" if errors.positive?
exit(failed.empty? && errors.zero? && count == ORIGINAL_EXAMPLES ? 0 : 1)
