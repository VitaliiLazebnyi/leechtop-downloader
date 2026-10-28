# typed: strict
# frozen_string_literal: true

require 'down'
require 'sorbet-runtime'

module LeechtopDownloader
  # Turns file names that come from the network (the page title or the Content-Disposition header) into
  # names that are safe to create inside the destination directory.
  module Filename
    extend T::Sig

    # Path separators and the NUL byte cannot be part of a file name: a name containing them would write
    # outside the destination directory (or make the file system call raise).
    UNSAFE_CHARACTERS = %r{[/\\\0]}
    private_constant :UNSAFE_CHARACTERS

    # Replaces every character that cannot be part of a single file name with an underscore.
    # @param name [String] The file name suggested by the remote server.
    # @return [String] The name with path separators and NUL bytes replaced.
    sig { params(name: String).returns(String) }
    def self.sanitize(name)
      name.gsub(UNSAFE_CHARACTERS, '_')
    end

    # The name to save a download as: the name the server sent, else the one shown on the page, else a name
    # made from the current UTC time (LT-REQ-005).
    # @param io [IO, StringIO, Tempfile] The downloaded stream.
    # @param page_filename [String] The name of the file shown on the page.
    # @return [String] The file name.
    sig { params(io: T.any(IO, StringIO, Tempfile), page_filename: String).returns(String) }
    def self.for_download(io, page_filename)
      original = io.original_filename if io.is_a?(Down::NetHttp::DownloadedFile)
      return repair_encoding(original) if original
      return page_filename unless page_filename.empty?

      "leechtop_#{Time.now.utc.to_i}.bin"
    end

    # Fixes mojibake (UTF-8 bytes that were decoded as ISO-8859-1) back to valid UTF-8.
    # @param name [String] The possibly corrupted string.
    # @return [String] The repaired string, or +name+ itself when it is not mojibake.
    sig { params(name: String).returns(String) }
    def self.repair_encoding(name)
      fixed = name.encode(Encoding::ISO_8859_1).force_encoding(Encoding::UTF_8)
      fixed.valid_encoding? ? fixed : name
    rescue EncodingError
      name
    end
  end
end
