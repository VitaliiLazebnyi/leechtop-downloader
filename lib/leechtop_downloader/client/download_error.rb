# typed: strict
# frozen_string_literal: true

require 'down'
require 'sorbet-runtime'

module LeechtopDownloader
  # Client handles the network requests to Leechtop.
  class Client
    # Error class for download-specific errors.
    class DownloadError < Error
      extend T::Sig

      # The message of a download whose file no longer exists.
      NOT_FOUND = 'The file could not be found on the host server (404 Not Found). It may have been deleted.'
      private_constant :NOT_FOUND

      # The message that describes why a download failed.
      # @param error [StandardError] The failure.
      # @return [String] The message.
      sig { params(error: StandardError).returns(String) }
      def self.describe(error)
        case error
        when Down::NotFound then NOT_FOUND
        when Down::ClientError, Down::ServerError then "The host server rejected the download: #{error}"
        else "Network or extraction failure: #{error}"
        end
      end
    end
  end
end
