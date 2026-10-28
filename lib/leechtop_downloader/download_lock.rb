# typed: strict
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'sorbet-runtime'

module LeechtopDownloader
  # A lock file next to a download, so that two processes never download the same file at once.
  class DownloadLock < T::Struct
    extend T::Sig

    # @return [String] The URL being downloaded.
    const :url, String
    # @return [String] The name of the file, or an empty string when it is not known yet.
    const :filename, String
    # @return [String] The download destination directory.
    const :directory, String

    # Creates the file, and fails when it already exists.
    CREATE_NEW = T.let(File::WRONLY | File::CREAT | File::EXCL, Integer)
    private_constant :CREATE_NEW

    # Runs the block while holding the lock, and removes the lock file afterwards. When another process
    # holds the lock, prints that the file is skipped instead.
    # @yield The block to execute once the lock is acquired.
    sig { params(blk: T.proc.void).void }
    def hold(&blk)
      return report_busy unless acquire

      begin
        yield
      ensure
        FileUtils.rm_f(path)
      end
    end

    private

    # Creates the lock file, unless it already exists.
    # @return [Boolean] true if the lock was acquired, false if another process holds it.
    sig { returns(T::Boolean) }
    def acquire
      File.new(path, CREATE_NEW).close
      true
    rescue Errno::EEXIST
      false
    end

    # The lock file: named after the file, or after the MD5 digest of the URL when the file name is not known.
    # @return [String] The path of the lock file.
    sig { returns(String) }
    def path
      File.join(directory, "#{filename.empty? ? Digest::MD5.hexdigest(url) : filename}.lock")
    end

    # Prints that the file is skipped because another process is downloading it.
    sig { void }
    def report_busy
      name = filename.empty? ? 'File' : "File #{filename}"
      puts "#{name} is currently being downloaded by another process. Skipping."
    end
  end
end
