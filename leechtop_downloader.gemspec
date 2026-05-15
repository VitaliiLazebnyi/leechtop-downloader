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
  spec.required_ruby_version = '>= 3.2.0'
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
  spec.add_dependency 'dotenv', '~> 3.0'
  spec.add_dependency 'down', '~> 5.0'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'nokogiri', '~> 1.0'
  spec.add_dependency 'sorbet-runtime', '~> 0.6'
  spec.add_dependency 'thor', '~> 1.0'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rubocop', '~> 1.86'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop-sorbet', '~> 0.12'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'sorbet', '~> 0.6'
  spec.add_development_dependency 'tapioca', '~> 0.19'
  spec.add_development_dependency 'webmock', '~> 3.26'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'yard-sorbet', '~> 0.9'
end
