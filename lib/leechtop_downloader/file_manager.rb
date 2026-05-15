# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "fileutils"

module LeechtopDownloader
  # FileManager handles the physical saving of files using Metric/UTC standards.
  class FileManager
    extend T::Sig

    # LT-REQ-003, LT-REQ-004, LT-REQ-005, LT-REQ-006, BUG-LT-001
    sig { params(io: T.any(IO, StringIO, Tempfile), filename: String, destination: String).returns([Integer, String]) }
    def self.save_stream(io, filename, destination = ".")
      # Enforcement of UTC and Metric standards
      FileUtils.mkdir_p(destination)
      resolved_filename = resolve_filename(filename, destination)
      filepath = File.join(destination, resolved_filename)

      bytes_written = write_stream(io, filepath)

      # Enforce UTC timestamps on the generated file
      utc_now = Time.now.utc
      File.utime(utc_now, utc_now, filepath)

      [bytes_written, resolved_filename]
    end

    sig { params(original_filename: String, directory: String).returns(String) }
    def self.resolve_filename(original_filename, directory)
      return original_filename unless File.exist?(File.join(directory, original_filename))

      ext = File.extname(original_filename)
      base = File.basename(original_filename, ext)
      find_unique_filename(base, ext, directory, original_filename)
    end

    sig { params(base: String, ext: String, dir: String, orig: String).returns(String) }
    def self.find_unique_filename(base, ext, dir, orig)
      counter = 1
      loop do
        name = "#{base}_#{counter}#{ext}"
        unless File.exist?(File.join(dir, name))
          puts "Warning: File '#{orig}' already exists. Saving as '#{name}'"
          return name
        end
        counter += 1
      end
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
