# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "dotenv/load"

module LeechtopDownloader
  class Error < StandardError; end
end

require_relative "leechtop_downloader/file_manager"
require_relative "leechtop_downloader/client"
require_relative "leechtop_downloader/cli"
