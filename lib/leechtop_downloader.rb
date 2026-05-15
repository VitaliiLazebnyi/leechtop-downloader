# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'dotenv/load'

# The main module for the LeechtopDownloader application.
module LeechtopDownloader
  # Standard Error class for the application.
  class Error < StandardError; end
end

require_relative 'leechtop_downloader/version'
require_relative 'leechtop_downloader/file_manager'
require_relative 'leechtop_downloader/client'
require_relative 'leechtop_downloader/cli'
