# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::FileManager do
  let(:filename) { 'test_file.bin' }
  let(:downloads_dir) { 'downloads' }
  let(:filepath) { File.join(downloads_dir, filename) }
  let(:file_content) { 'mock data' }
  let(:io) { StringIO.new(file_content) }

  describe '.save_stream' do
    it 'LT-REQ-003, BUG-LT-001: saves the IO stream into the specified directory, creating it' do
      described_class.save_stream(io, filename, downloads_dir)
      expect(File.read(filepath)).to eq(file_content)
    end

    it 'LT-REQ-004: returns the metric byte size of the written file and its filename' do
      expect(described_class.save_stream(StringIO.new('ポケ'), filename, downloads_dir)).to eq([6, filename])
    end

    it 'saves into the current directory by default' do
      described_class.save_stream(io, filename)
      expect(File.read(filename)).to eq(file_content)
    end

    it 'LT-REQ-004: copies the stream in chunks of 8 kB (metric)' do
      allow(io).to receive(:read).and_call_original
      described_class.save_stream(io, filename, downloads_dir)
      expect(io).to have_received(:read).with(8_000).twice
    end

    it 'copies streams larger than one chunk completely' do
      content = Random.new(1).bytes(20_000)
      described_class.save_stream(StringIO.new(content), filename, downloads_dir)
      expect(File.binread(filepath)).to eq(content)
    end

    it 'LT-REQ-005: stamps the saved file with the current UTC time' do
      now = Time.utc(2026, 1, 1, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now.getlocal('+05:00'))
      described_class.save_stream(io, filename, downloads_dir)
      expect([File.atime(filepath), File.mtime(filepath)]).to eq([now, now])
    end

    it 'treats a destination whose name starts with a pipe as a directory, never as a command' do
      described_class.save_stream(io, filename, '|echo')
      expect(File.read(File.join('|echo', filename))).to eq(file_content)
    end

    it 'never writes outside the destination directory' do
      described_class.save_stream(io, '../escaped.bin', downloads_dir)
      expect(Dir.children(Dir.pwd)).to eq([downloads_dir])
    end

    it 'saves a name with path separators as a single file name' do
      expect(described_class.save_stream(io, '../escaped.bin', downloads_dir)).to eq([9, '.._escaped.bin'])
    end

    context 'when LT-REQ-006 is triggered and the file already exists' do
      before do
        FileUtils.mkdir_p(downloads_dir)
        File.write(filepath, 'existing data')
      end

      it 'does not overwrite the existing file', :aggregate_failures do
        expect { described_class.save_stream(io, filename, downloads_dir) }.to output.to_stdout
        expect(File.read(filepath)).to eq('existing data')
      end

      it 'appends _1 to the filename and warns about it', :aggregate_failures do
        expect { described_class.save_stream(io, filename, downloads_dir) }
          .to output("Warning: File 'test_file.bin' already exists. Saving as 'test_file_1.bin'\n").to_stdout
        expect(File.read(File.join(downloads_dir, 'test_file_1.bin'))).to eq(file_content)
      end

      it 'appends _2 if _1 also exists', :aggregate_failures do
        File.write(File.join(downloads_dir, 'test_file_1.bin'), 'existing _1 data')
        expect { described_class.save_stream(io, filename, downloads_dir) }
          .to output(/Saving as 'test_file_2.bin'/).to_stdout
        expect(File.read(File.join(downloads_dir, 'test_file_2.bin'))).to eq(file_content)
      end

      it 'returns the byte size and the new filename', :aggregate_failures do
        result = nil
        expect { result = described_class.save_stream(io, filename, downloads_dir) }.to output.to_stdout
        expect(result).to eq([file_content.bytesize, 'test_file_1.bin'])
      end

      it 'appends the counter to names without an extension' do
        File.write(File.join(downloads_dir, 'README'), '')
        expect { described_class.save_stream(io, 'README', downloads_dir) }.to output(/Saving as 'README_1'/).to_stdout
      end
    end
  end
end
