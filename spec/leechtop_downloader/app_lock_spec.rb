# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::AppLock do
  let(:lock_path) { File.join(Dir.tmpdir, 'leechtop_downloader.lock') }

  describe '.hold' do
    it 'runs the block while holding the lock file in the temporary directory' do
      expect { |block| described_class.hold(&block) }.to yield_control.once
    end

    it 'holds an exclusive lock on the lock file while the block runs' do
      described_class.hold do
        expect(File.open(lock_path, 'r') { |file| file.flock(File::LOCK_EX | File::LOCK_NB) }).to be(false)
      end
    end

    it 'opens the lock file with File.open, for writing' do
      allow(File).to receive(:open).and_call_original
      described_class.hold { nil }
      expect(File).to have_received(:open).with(lock_path, 'w')
    end

    it 'closes the lock file after the block' do
      described_class.hold { nil }
      open_locks = ObjectSpace.each_object(File).select { |file| !file.closed? && file.path == lock_path }
      expect(open_locks).to be_empty
    end

    it 'releases the lock after the block' do
      described_class.hold { nil }
      expect(File.open(lock_path, 'r') { |file| file.flock(File::LOCK_EX | File::LOCK_NB) }).to eq(0)
    end

    context 'when another instance holds the lock (LT-REQ-007)' do
      around do |example|
        File.open(lock_path, 'w') do |file|
          file.flock(File::LOCK_EX)
          example.run
        end
      end

      it 'exits with status 1 and an error message, without running the block', :aggregate_failures do
        expect { described_class.hold { raise 'must not run' } }
          .to output("Error: Another instance of leechtop downloader is already running.\n").to_stdout
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end
  end
end
