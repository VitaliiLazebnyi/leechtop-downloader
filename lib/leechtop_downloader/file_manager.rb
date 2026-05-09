# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "fileutils"

module LeechtopDownloader
  # FileManager handles the physical saving of files using Metric/UTC standards.
  class FileManager
    extend T::Sig

    # LT-REQ-003, LT-REQ-004, LT-REQ-005
    sig { params(io: T.any(IO, StringIO, Tempfile), filename: String).returns(Integer) }
    def self.save_stream(io, filename)
      # Enforcement of UTC and Metric standards
      FileUtils.mkdir_p("downloads")
      filepath = File.join("downloads", filename)

      bytes_written = write_stream(io, filepath)

      # Enforce UTC timestamps on the generated file
      utc_now = Time.now.utc
      File.utime(utc_now, utc_now, filepath)

      bytes_written
    end

    sig { params(io: T.any(IO, StringIO, Tempfile), filepath: String).returns(Integer) }
    def self.write_stream(io, filepath)
      bytes_written = 0
      File.open(filepath, "wb") do |file|
        while (chunk = io.read(8192)) # 8 KB metric chunking
          file.write(chunk)
          bytes_written += chunk.bytesize
        end
      end
      bytes_written
    end
  end
end
