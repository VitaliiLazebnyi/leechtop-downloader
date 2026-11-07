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
    # An exclusive lock, requested without waiting for it.
    LOCK_WITHOUT_WAITING = T.let(File::LOCK_EX | File::LOCK_NB, Integer)
    private_constant :FILENAME, :LOCK_WITHOUT_WAITING

    # Runs the block while holding the application-wide lock, or exits with status 1 when another instance
    # holds it.
    # @yield The block to execute once the lock is acquired.
    sig { params(blk: T.proc.void).void }
    def self.hold(&blk)
      File.open(File.join(Dir.tmpdir, FILENAME), 'w') do |file|
        unless file.flock(LOCK_WITHOUT_WAITING)
          puts 'Error: Another instance of leechtop downloader is already running.'
          exit(1)
        end

        yield
      end
    end
  end
end
