# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeechtopDownloader::FileManager do
  let(:filename) { "test_file.bin" }
  let(:downloads_dir) { "downloads" }
  let(:filepath) { File.join(downloads_dir, filename) }
  let(:file_content) { "mock data" }
  let(:io) { StringIO.new(file_content) }

  before do
    FileUtils.rm_rf(downloads_dir)
  end

  after do
    FileUtils.rm_rf(downloads_dir)
  end

  describe ".save_stream" do
    it "LT-REQ-003: saves the IO stream to the downloads directory" do
      described_class.save_stream(io, filename)
      expect(File.exist?(filepath)).to be(true)
      expect(File.read(filepath)).to eq(file_content)
    end

    it "LT-REQ-004: returns the metric byte size of the written file" do
      bytes = described_class.save_stream(io, filename)
      expect(bytes).to eq(file_content.bytesize)
    end

    it "LT-REQ-005: enforces UTC timestamp on the saved file" do
      now = Time.now.utc
      allow(Time).to receive(:now).and_return(now)
      described_class.save_stream(io, filename)

      stat = File.stat(filepath)
      # Some file systems have slight sub-second truncation, but testing to integer seconds is deterministic
      expect(stat.mtime.utc.to_i).to eq(now.to_i)
    end
  end
end
