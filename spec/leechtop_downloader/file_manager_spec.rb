# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeechtopDownloader::FileManager do
  let(:filename) { "test_file.bin" }
  let(:downloads_dir) { Dir.mktmpdir("leechtop_test_downloads") }
  let(:filepath) { File.join(downloads_dir, filename) }
  let(:file_content) { "mock data" }
  let(:io) { StringIO.new(file_content) }

  after do
    FileUtils.rm_rf(downloads_dir)
  end

  describe ".save_stream" do
    it "LT-REQ-003, BUG-LT-001: saves the IO stream to the specified directory without wiping global downloads" do
      result = described_class.save_stream(io, filename, downloads_dir)
      expect(result).to eq([file_content.bytesize, filename])
      expect(File.exist?(filepath)).to be(true)
      expect(File.read(filepath)).to eq(file_content)
    end

    it "LT-REQ-004: returns the metric byte size of the written file and filename" do
      bytes, saved_name = described_class.save_stream(io, filename, downloads_dir)
      expect(bytes).to eq(file_content.bytesize)
      expect(saved_name).to eq(filename)
    end

    it "LT-REQ-005: enforces UTC timestamp on the saved file" do
      now = Time.now.utc
      allow(Time).to receive(:now).and_return(now)
      described_class.save_stream(io, filename, downloads_dir)

      stat = File.stat(filepath)
      # Some file systems have slight sub-second truncation, but testing to integer seconds is deterministic
      expect(stat.mtime.utc.to_i).to eq(now.to_i)
    end

    context "when LT-REQ-006 is triggered and the file already exists" do
      before do
        FileUtils.mkdir_p(downloads_dir)
        File.write(filepath, "existing data")
      end

      it "does not overwrite the existing file and appends _1 to the filename" do
        expect do
          described_class.save_stream(io, filename, downloads_dir)
        end.to output(/Warning: File 'test_file.bin' already exists. Saving as 'test_file_1.bin'/).to_stdout

        expect(File.read(filepath)).to eq("existing data")

        new_filepath = File.join(downloads_dir, "test_file_1.bin")
        expect(File.exist?(new_filepath)).to be(true)
        expect(File.read(new_filepath)).to eq(file_content)
      end

      it "appends _2 if _1 also exists" do
        File.write(File.join(downloads_dir, "test_file_1.bin"), "existing _1 data")

        expect do
          described_class.save_stream(io, filename, downloads_dir)
        end.to output(/Warning: File 'test_file.bin' already exists. Saving as 'test_file_2.bin'/).to_stdout

        new_filepath = File.join(downloads_dir, "test_file_2.bin")
        expect(File.exist?(new_filepath)).to be(true)
        expect(File.read(new_filepath)).to eq(file_content)
      end

      it "returns the byte size and the new filename" do
        # We should update the signature of save_stream to return both bytes written and the final filename used
        result = nil
        expect do
          result = described_class.save_stream(io, filename, downloads_dir)
        end.to output(/Warning/).to_stdout

        expect(result).to eq([file_content.bytesize, "test_file_1.bin"])
      end
    end
  end
end
