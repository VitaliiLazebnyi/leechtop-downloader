# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'tmpdir'

module LeechtopDownloader
  # CLIHelpers provides shared utility methods for CLI operations
  module CLIHelpers
    extend T::Sig

    # Acquires an application-level lock to prevent concurrent executions.
    # @yield The block to execute if the lock is acquired.
    sig { params(blk: T.proc.void).void }
    def with_app_lock(&blk)
      lock_path = File.join(Dir.tmpdir, 'leechtop_downloader.lock')
      File.open(lock_path, 'w') do |file|
        unless file.flock(File::LOCK_EX | File::LOCK_NB)
          Kernel.puts 'Error: Another instance of leechtop downloader is already running.'
          Kernel.exit(1)
        end

        blk.call
      end
    end

    # Checks if a download should be skipped because the file already exists.
    # @param filename_hint [String] The name of the file.
    # @param skip_existing [T::Boolean] Whether to skip existing files.
    # @param destination [String] The download destination directory.
    # @return [T::Boolean] true if the download should be skipped, false otherwise.
    sig { params(filename_hint: String, skip_existing: T::Boolean, destination: String).returns(T::Boolean) }
    def skip_download?(filename_hint, skip_existing, destination)
      return false unless skip_existing && !filename_hint.empty?

      if File.exist?(File.join(destination, filename_hint))
        Kernel.puts "File #{filename_hint} already exists. Skipping."
        true
      else
        false
      end
    end

    # Generates a lock file path for a specific download.
    # @param url [String] The URL being downloaded.
    # @param filename_hint [String] The name of the file.
    # @param destination [String] The download destination directory.
    # @return [String] The lock file path.
    sig { params(url: String, filename_hint: String, destination: String).returns(String) }
    def lock_path_for(url, filename_hint, destination)
      lock_filename = filename_hint.empty? ? "#{Digest::MD5.hexdigest(url)}.lock" : "#{filename_hint}.lock"
      File.join(destination, lock_filename)
    end

    # Attempts to acquire a file-based lock.
    # @param lock_path [String] The path to the lock file.
    # @return [T::Boolean] true if lock acquired successfully, false if already exists.
    sig { params(lock_path: String).returns(T::Boolean) }
    def acquire_lock(lock_path)
      File.new(lock_path, File::WRONLY | File::CREAT | File::EXCL).close
      true
    rescue Errno::EEXIST
      false
    end

    # Prints a message indicating a file is currently being downloaded.
    # @param filename_hint [String] The name of the file.
    sig { params(filename_hint: String).void }
    def skip_locked(filename_hint)
      name = filename_hint.empty? ? 'File' : "File #{filename_hint}"
      Kernel.puts "#{name} is currently being downloaded by another process. Skipping."
    end

    # Fixes mojibake or broken encoding strings to valid UTF-8.
    # @param name [String] The possibly corrupted string.
    # @return [String] A valid UTF-8 string.
    sig { params(name: String).returns(String) }
    def fix_encoding(name)
      fixed = name.encode('iso-8859-1').force_encoding('utf-8')
      fixed.valid_encoding? ? fixed : name
    rescue EncodingError
      name
    end
  end
end
