# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'tmpdir'

module LeechtopDownloader
  # Lets only one instance of the downloader run at a time on this machine (LT-REQ-007).
  module AppLock
    extend T::Sig

    # Name of the lock file in the system's temporary directory.
    FILENAME = 'leechtop_downloader.lock'
    private_constant :FILENAME

    # Runs the block while holding the application-wide lock, or exits with status 1 when another instance
    # holds it.
    # @yield The block to execute once the lock is acquired.
    sig { params(blk: T.proc.void).void }
    def self.hold(&blk)
      File.open(File.join(Dir.tmpdir, FILENAME), 'w') do |file|
        unless file.flock(File::LOCK_EX | File::LOCK_NB)
          Kernel.puts 'Error: Another instance of leechtop downloader is already running.'
          Kernel.exit(1)
        end

        yield
      end
    end
  end
end
