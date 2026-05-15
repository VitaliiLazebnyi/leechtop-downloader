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
  if $PROGRAM_NAME.end_with?('gem') && File.exist?(File.expand_path('~/.gem/private_key.pem'))
    spec.signing_key = File.expand_path('~/.gem/private_key.pem')
  end
  spec.required_ruby_version = '>= 3.0.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = %w[
    BUGS.md
    Gemfile
    LICENSE.txt
    README.md
    REQUIREMENTS.md
    leechtop_downloader.gemspec
  ] + Dir.glob('{exe,lib,certs}/**/*', base: __dir__).select do |f|
    File.file?(File.expand_path(f, __dir__))
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'dotenv', '~> 3.1'
  spec.add_dependency 'down', '~> 5.4'
  spec.add_dependency 'faraday', '~> 2.12'
  spec.add_dependency 'nokogiri', '~> 1.19'
  spec.add_dependency 'sorbet-runtime'
  spec.add_dependency 'thor', '~> 1.3'

  # Development dependencies
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'rubocop-sorbet'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'yard-sorbet'
end
