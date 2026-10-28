# typed: strict
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'sorbet-runtime'

module LeechtopDownloader
  # A lock file next to a download, so that two processes never download the same file at once.
  class DownloadLock
    extend T::Sig

    # @param url [String] The URL being downloaded.
    # @param filename [String] The name of the file, or an empty string when it is not known yet.
    # @param directory [String] The download destination directory.
    sig { params(url: String, filename: String, directory: String).void }
    def initialize(url:, filename:, directory:)
      @filename = filename
      lock_name = filename.empty? ? Digest::MD5.hexdigest(url) : filename
      @path = T.let(File.join(directory, "#{lock_name}.lock"), String)
    end

    # Runs the block while holding the lock, and removes the lock file afterwards. When another process
    # holds the lock, prints that the file is skipped instead.
    # @yield The block to execute once the lock is acquired.
    sig { params(blk: T.proc.void).void }
    def hold(&blk)
      return report_busy unless acquire

      begin
        yield
      ensure
        FileUtils.rm_f(@path)
      end
    end

    private

    # Creates the lock file, unless it already exists.
    # @return [Boolean] true if the lock was acquired, false if another process holds it.
    sig { returns(T::Boolean) }
    def acquire
      File.new(@path, File::WRONLY | File::CREAT | File::EXCL).close
      true
    rescue Errno::EEXIST
      false
    end

    # Prints that the file is skipped because another process is downloading it.
    sig { void }
    def report_busy
      name = @filename.empty? ? 'File' : "File #{@filename}"
      puts "#{name} is currently being downloaded by another process. Skipping."
    end
  end
end
