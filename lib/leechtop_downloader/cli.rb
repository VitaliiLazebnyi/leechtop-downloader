# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'thor'

module LeechtopDownloader
  # CLI is the Thor application for handling commands.
  class CLI < Thor
    extend T::Sig

    # Ensure Thor exits with an error status on failure.
    # @return [Boolean] true
    sig { returns(T::Boolean) }
    def self.exit_on_failure?
      true
    end

    method_option :skip_existing, type: :boolean, default: true, desc: 'Skip downloading already existing files'
    method_option :destination, type: :string, default: '.', desc: 'Destination folder for downloaded files'
    desc 'download URL_OR_FILE...', 'Download one or more URLs (or a text file with links) from leechtop.com'
    # LT-REQ-001, LT-REQ-002
    # Main entry point to download files.
    # @param urls [Array<String>] The URLs or file paths to download from.
    sig { params(urls: String).void }
    def download(*urls)
      report_missing_urls if urls.empty?
      downloader = Downloader.new(skip_existing: options.fetch(:skip_existing, true),
                                  destination: options.fetch(:destination, '.'))
      AppLock.hold { urls.each { |arg| downloader.process_argument(arg) } }
    end

    private

    # Prints the usage error of a download without URLs and exits with status 1.
    sig { returns(T.noreturn) }
    def report_missing_urls
      puts 'Error: You must provide at least one URL or file path.'
      exit 1
    end
  end
end
