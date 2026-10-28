# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::DownloadLock do
  subject(:lock) { described_class.new(url: url, filename: 'example.bin', directory: 'downloads') }

  let(:url) { 'https://leechtop.com/example' }

  before { FileUtils.mkdir_p('downloads') }

  describe '#hold' do
    it 'creates the lock file next to the download while the block runs' do
      lock.hold { expect(File).to exist('downloads/example.bin.lock') }
    end

    it 'runs the block once' do
      expect { |block| lock.hold(&block) }.to yield_control.once
    end

    it 'removes the lock file after the block' do
      lock.hold { nil }
      expect(Dir.children('downloads')).to be_empty
    end

    it 'removes the lock file when the block fails', :aggregate_failures do
      expect { lock.hold { raise LeechtopDownloader::Error, 'failure' } }.to raise_error(LeechtopDownloader::Error)
      expect(Dir.children('downloads')).to be_empty
    end

    it 'names the lock after the MD5 digest of the URL when the filename is not known' do
      described_class.new(url: url, filename: '', directory: 'downloads').hold do
        expect(Dir.children('downloads')).to eq(["#{Digest::MD5.hexdigest(url)}.lock"])
      end
    end

    context 'when another process holds the lock' do
      before { File.write('downloads/example.bin.lock', '') }

      it 'skips the block and reports the file as busy' do
        expect { lock.hold { raise 'must not run' } }
          .to output("File example.bin is currently being downloaded by another process. Skipping.\n").to_stdout
      end

      it 'leaves the lock of the other process in place', :aggregate_failures do
        expect { lock.hold { nil } }.to output.to_stdout
        expect(File).to exist('downloads/example.bin.lock')
      end

      it 'reports an unnamed file as busy' do
        File.write("downloads/#{Digest::MD5.hexdigest(url)}.lock", '')
        expect { described_class.new(url: url, filename: '', directory: 'downloads').hold { nil } }
          .to output("File is currently being downloaded by another process. Skipping.\n").to_stdout
      end
    end
  end
end
