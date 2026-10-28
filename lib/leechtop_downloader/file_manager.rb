# typed: strict
# frozen_string_literal: true

require 'fileutils'
require 'sorbet-runtime'

module LeechtopDownloader
  # FileManager handles the physical saving of files using Metric/UTC standards.
  class FileManager
    extend T::Sig

    # Size of the chunks the stream is copied in: 8 kB, a metric unit as LT-REQ-004 requires (the previous
    # 8192 bytes were 8 KiB, a binary one).
    CHUNK_SIZE = 8_000
    private_constant :CHUNK_SIZE

    # LT-REQ-003, LT-REQ-004, LT-REQ-005, LT-REQ-006, BUG-LT-001
    # Saves an IO stream to the specified destination directory.
    # @param io [IO, StringIO, Tempfile] The stream to read from.
    # @param filename [String] The name of the file to save.
    # @param destination [String] The directory where the file will be saved.
    # @return [Array<Integer, String>] The number of bytes written and the final resolved filename.
    sig { params(io: T.any(IO, StringIO, Tempfile), filename: String, destination: String).returns([Integer, String]) }
    def self.save_stream(io, filename, destination = '.')
      FileUtils.mkdir_p(destination)
      resolved_filename = resolve_filename(Filename.sanitize(filename), destination)
      [write_stream(io, File.join(destination, resolved_filename)), resolved_filename]
    end

    # Resolves a unique filename within the specified directory, warning when the name is taken (LT-REQ-006).
    # @param original_filename [String] The original requested filename.
    # @param directory [String] The destination directory.
    # @return [String] A unique filename string.
    sig { params(original_filename: String, directory: String).returns(String) }
    def self.resolve_filename(original_filename, directory)
      return original_filename unless File.exist?(File.join(directory, original_filename))

      unique_filename = find_unique_filename(original_filename, directory)
      puts "Warning: File '#{original_filename}' already exists. Saving as '#{unique_filename}'"
      unique_filename
    end

    # Finds the first free filename made by appending an incremental counter to the base name.
    # @param original_filename [String] The filename that is already taken.
    # @param directory [String] The directory to check for existence.
    # @return [String] A unique filename string.
    sig { params(original_filename: String, directory: String).returns(String) }
    def self.find_unique_filename(original_filename, directory)
      ext = File.extname(original_filename)
      base = File.basename(original_filename, ext)
      counter = 1
      counter += 1 while File.exist?(File.join(directory, "#{base}_#{counter}#{ext}"))
      "#{base}_#{counter}#{ext}"
    end

    # Writes chunks of data from an IO stream to a physical file and stamps it with the current UTC time.
    # @param io [IO, StringIO, Tempfile] The stream to read from.
    # @param filepath [String] The full path to the destination file.
    # @return [Integer] The total number of bytes written.
    sig { params(io: T.any(IO, StringIO, Tempfile), filepath: String).returns(Integer) }
    def self.write_stream(io, filepath)
      bytes_written = File.open(filepath, 'wb') { |file| copy_chunks(io, file) }
      # LT-REQ-005: enforce UTC timestamps on the generated file
      utc_now = Time.now.utc
      File.utime(utc_now, utc_now, filepath)
      bytes_written
    end

    # Copies a stream into a file in chunks of CHUNK_SIZE bytes.
    # @param io [IO, StringIO, Tempfile] The stream to read from.
    # @param file [File] The file to write to.
    # @return [Integer] The total number of bytes written.
    sig { params(io: T.any(IO, StringIO, Tempfile), file: File).returns(Integer) }
    def self.copy_chunks(io, file)
      bytes_written = 0
      while (chunk = io.read(CHUNK_SIZE))
        bytes_written += file.write(chunk)
      end
      bytes_written
    end
    private_class_method :copy_chunks
  end
end
