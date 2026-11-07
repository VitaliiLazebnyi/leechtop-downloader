# typed: false
# frozen_string_literal: true

require 'open3'
require 'spec_helper'

RSpec.describe LeechtopDownloader::CLI do
  let(:url) { 'https://leechtop.com/example' }

  describe '.exit_on_failure?' do
    it 'returns true to ensure Thor exits with an error status on failure' do
      expect(described_class.exit_on_failure?).to be(true)
    end
  end

  describe '#download' do
    before { stub_download(url, 'file data', filename: 'example.bin') }

    it 'LT-REQ-001: exits with an error if no URLs are provided', :aggregate_failures do
      expect { described_class.new.download }
        .to output("Error: You must provide at least one URL or file path.\n").to_stdout
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    it 'LT-REQ-002: downloads into the current directory by default', :aggregate_failures do
      expect { described_class.start(['download', url]) }.to output(/Successfully downloaded example.bin/).to_stdout
      expect(File.read('example.bin')).to eq('file data')
    end

    it 'uses the defaults when it is created without options' do
      File.write('example.bin', 'old')
      expect { described_class.new.download(url) }.to output(/already exists. Skipping/).to_stdout
    end

    it 'downloads into the --destination directory', :aggregate_failures do
      expect { described_class.start(['download', url, '--destination', 'out']) }.to output.to_stdout
      expect(Dir.children('out')).to eq(['example.bin'])
    end

    it 'skips existing files by default' do
      File.write('example.bin', 'old')
      expect { described_class.start(['download', url]) }.to output(/already exists. Skipping/).to_stdout
    end

    it 'downloads existing files again with --no-skip-existing' do
      File.write('example.bin', 'old')
      expect { described_class.start(['download', url, '--no-skip-existing']) }
        .to output(/Successfully downloaded example_1.bin/).to_stdout
    end

    it 'processes every argument, including text files of links' do
      File.write('links.txt', "#{url}\n")
      expect { described_class.start(['download', 'links.txt', url]) }
        .to output(/example.bin \(9 bytes\).*already exists. Skipping/m).to_stdout
    end

    it 'LT-REQ-007: exits with an error if another instance is already running' do
      File.open(File.join(Dir.tmpdir, 'leechtop_downloader.lock'), 'w') do |file|
        file.flock(File::LOCK_EX)
        expect { described_class.start(['download', url]) }
          .to output(/Another instance of leechtop downloader is already running/).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  describe 'the leechtop executable' do
    let(:root) { File.expand_path('../..', __dir__) }

    it 'LT-REQ-001: runs the CLI without printing any warning' do
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', File.join(root, 'lib'),
                                              File.join(root, 'exe', 'leechtop'), 'help', 'download')
      expect([stdout.lines.first, stderr, status.success?]).to eq(["Usage:\n", '', true])
    end
  end
end
