# frozen_string_literal: true

require_relative 'lib/leechtop_downloader/version'

Gem::Specification.new do |spec|
  spec.name          = 'leechtop_downloader'
  spec.version       = LeechtopDownloader::VERSION
  spec.authors       = ['Vitalii Lazebnyi']
  spec.email         = ['vitalii.lazebnyi.github@gmail.com']

  spec.summary       = 'CLI utility to download files from leechtop.com.'
  spec.description   = 'A robust command-line tool that automates extracting direct ' \
                       'download links and saving files from leechtop.com. ' \
                       'Supports batch processing, duplicate skipping, and safe concurrency.'
  spec.homepage      = 'https://github.com/VitaliiLazebnyi/leechtop-downloader'
  spec.license       = 'MIT'
  spec.cert_chain    = ['certs/leechtop_downloader-public_cert.pem']
  if $PROGRAM_NAME.end_with?('gem') && File.exist?(File.expand_path('~/.gem/gem-private_key.pem'))
    spec.signing_key = File.expand_path('~/.gem/gem-private_key.pem')
  end
  spec.required_ruby_version = '>= 3.3.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = %w[
    Gemfile
    LICENSE.txt
    README.md
    leechtop_downloader.gemspec
  ] + Dir.glob('{exe,lib,certs}/**/*', base: __dir__).select do |f|
    File.file?(File.expand_path(f, __dir__))
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'dotenv', '~> 3.2'
  spec.add_dependency 'down', '~> 5.6'
  spec.add_dependency 'faraday', '~> 2.15'
  spec.add_dependency 'nokogiri', '~> 1.19'
  spec.add_dependency 'sorbet-runtime', '~> 0.6'
  spec.add_dependency 'thor', '~> 1.5'

  # Development dependencies
  spec.add_development_dependency 'bundler-audit', '~> 0.9'
  spec.add_development_dependency 'flay', '~> 2.14'
  spec.add_development_dependency 'mutant-rspec', '~> 0.17'
  spec.add_development_dependency 'rake', '~> 13.4'
  spec.add_development_dependency 'reek', '~> 6.6'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rubocop', '~> 1.92'
  spec.add_development_dependency 'rubocop-md', '~> 2.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.27'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.10'
  spec.add_development_dependency 'rubocop-sorbet', '~> 0.17'
  spec.add_development_dependency 'rubocop-thread_safety', '~> 0.8'
  spec.add_development_dependency 'simplecov', '~> 1.3'
  spec.add_development_dependency 'sorbet', '~> 0.6'
  spec.add_development_dependency 'tapioca', '~> 0.20'
  spec.add_development_dependency 'webmock', '~> 3.34'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'yard-sorbet', '~> 0.9'
end
