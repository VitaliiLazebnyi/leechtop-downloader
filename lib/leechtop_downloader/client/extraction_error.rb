# typed: strict
# frozen_string_literal: true

# Copyright (c) 2026 Vitalii Lazebnyi

module LeechtopDownloader
  class Client
    # Raised when a page or a server response does not contain what a download needs (the download button, its
    # tokens, the nonce or the direct link).
    class ExtractionError < Error; end
  end
end
