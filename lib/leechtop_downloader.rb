# typed: strict
# frozen_string_literal: true

require 'dotenv/load'
require 'sorbet-runtime'

# The main module for the LeechtopDownloader application.
module LeechtopDownloader
  # Standard Error class for the application.
  class Error < StandardError; end
end

require_relative 'leechtop_downloader/app_lock'
require_relative 'leechtop_downloader/cli'
require_relative 'leechtop_downloader/client'
require_relative 'leechtop_downloader/download_lock'
require_relative 'leechtop_downloader/downloader'
require_relative 'leechtop_downloader/file_manager'
require_relative 'leechtop_downloader/filename'
require_relative 'leechtop_downloader/version'
