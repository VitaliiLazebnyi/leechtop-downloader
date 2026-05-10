# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeechtopDownloader::CLI do
  let(:cli) { described_class.new }

  describe ".exit_on_failure?" do
    it "returns true to ensure Thor exits with an error status on failure" do
      expect(described_class.exit_on_failure?).to be(true)
    end
  end

  describe "#download" do
    let(:url) { "https://leechtop.com/example.bin" }
    let(:io) { StringIO.new("testdata") }
    let(:bytes) { 8 }

    before do
      # Provide a stub for IO so we can attach an original_filename method
      io.define_singleton_method(:original_filename) do
        "example.bin"
      end
      allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_return({ html: "<html></html>",
                                                                                           filename: "example.bin" })
      allow(LeechtopDownloader::Client).to receive(:download_from_html).with("<html></html>").and_return(io)
      allow(LeechtopDownloader::FileManager).to receive(:save_stream).and_return(bytes)
    end

    it "LT-REQ-001: Exits with error if no URLs are provided" do
      expect do
        cli.download
      end.to output(/Error: You must provide at least one URL or file path/).to_stdout.and raise_error(SystemExit)

      begin
        cli.download
      rescue SystemExit => e
        expect(e.status).to eq(1)
      end
    end

    it "LT-REQ-002: Downloads and saves a provided URL" do
      expect do
        cli.download(url)
      end.to output(/Successfully downloaded example\.bin \(8 bytes\)/).to_stdout

      expect(LeechtopDownloader::Client).to have_received(:fetch_metadata).with(url)
      expect(LeechtopDownloader::Client).to have_received(:download_from_html).with("<html></html>")
      expect(LeechtopDownloader::FileManager).to have_received(:save_stream).with(io, "example.bin")
    end

    it "LT-REQ-007: Exits with error if another instance is already running" do
      # Mock File.open to yield a file stub that returns false for flock
      file_stub = instance_double(File)
      allow(file_stub).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(false)
      allow(File).to receive(:open).and_yield(file_stub)

      expect do
        cli.download(url)
      end.to output(/Error: Another instance of leechtop downloader is already running\./)
         .to_stdout
        .and raise_error(SystemExit)

      begin
        cli.download(url)
      rescue SystemExit => e
        expect(e.status).to eq(1)
      end
    end

    it "falls back to UTC timestamp based filename if original_filename is absent" do
      # Standard StringIO doesn't have original_filename unless stubbed
      raw_io = StringIO.new("testdata")
      allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_return({ html: "<html></html>",
                                                                                           filename: "" })
      allow(LeechtopDownloader::Client).to receive(:download_from_html).with("<html></html>").and_return(raw_io)

      now = Time.utc(2026, 1, 1, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now)
      expected_filename = "leechtop_#{now.to_i}.bin"

      expect do
        cli.download(url)
      end.to output(/Successfully downloaded #{expected_filename} \(8 bytes\)/).to_stdout

      expect(LeechtopDownloader::FileManager).to have_received(:save_stream).with(raw_io, expected_filename)
    end

    it "falls back to filename_hint if original_filename is absent" do
      raw_io = StringIO.new("testdata")
      allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_return({ html: "<html></html>",
                                                                                           filename: "hint.bin" })
      allow(LeechtopDownloader::Client).to receive(:download_from_html).with("<html></html>").and_return(raw_io)

      expect do
        cli.download(url)
      end.to output(/Successfully downloaded hint\.bin \(8 bytes\)/).to_stdout

      expect(LeechtopDownloader::FileManager).to have_received(:save_stream).with(raw_io, "hint.bin")
    end

    it "handles download errors gracefully" do
      error = LeechtopDownloader::Client::DownloadError.new("Mock failure")
      allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_raise(error)

      expect do
        cli.download(url)
      end.to output(/Error downloading #{Regexp.escape(url)}: Mock failure/).to_stdout
    end

    it "LT-REQ-006: skips downloading if the file already exists and skip_existing is true" do
      allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_return({ html: "<html></html>",
                                                                                           filename: "example.bin" })
      allow(File).to receive(:exist?).with("downloads/example.bin").and_return(true)

      expect do
        cli.download(url) # default skip_existing is true
      end.to output(/File example\.bin already exists\. Skipping\./).to_stdout

      expect(LeechtopDownloader::Client).not_to have_received(:download_from_html)
      expect(LeechtopDownloader::FileManager).not_to have_received(:save_stream)
    end

    context "when concurrent downloading occurs" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("downloads/example.bin").and_return(false)
        allow(File).to receive(:exist?).with("downloads/example.bin.lock").and_return(true)
        allow(FileUtils).to receive(:rm_f)
      end

      it "creates and cleans up a lock file during a successful download" do
        lock_file = instance_double(File, close: nil)
        allow(File).to receive(:new).with("downloads/example.bin.lock", File::WRONLY | File::CREAT | File::EXCL).and_return(lock_file)

        expect do
          cli.download(url)
        end.to output(/Successfully downloaded example\.bin \(8 bytes\)/).to_stdout

        expect(File).to have_received(:new).with("downloads/example.bin.lock", File::WRONLY | File::CREAT | File::EXCL)

        expect(FileUtils).to have_received(:rm_f).with("downloads/example.bin.lock")
      end

      it "skips downloading if a lock file already exists (Errno::EEXIST)" do
        allow(File).to receive(:new).with("downloads/example.bin.lock",
                                          File::WRONLY | File::CREAT | File::EXCL).and_raise(Errno::EEXIST)

        expect do
          cli.download(url)
        end.to output(/File example\.bin is currently being downloaded by another process\. Skipping\./).to_stdout

        expect(LeechtopDownloader::Client).not_to have_received(:download_from_html)
      end

      it "skips downloading if a lock file already exists and filename_hint is empty" do
        allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(url).and_return({ html: "<html></html>",
                                                                                             filename: "" })
        digest_lock_path = "downloads/#{Digest::MD5.hexdigest(url)}.lock"
        allow(File).to receive(:new).with(digest_lock_path, File::WRONLY | File::CREAT | File::EXCL).and_raise(Errno::EEXIST)

        expect do
          cli.download(url)
        end.to output(/File is currently being downloaded by another process\. Skipping\./).to_stdout

        expect(LeechtopDownloader::Client).not_to have_received(:download_from_html)
      end

      it "cleans up the lock file even if a DownloadError occurs" do
        lock_file = instance_double(File, close: nil)
        allow(File).to receive(:new).with("downloads/example.bin.lock", File::WRONLY | File::CREAT | File::EXCL).and_return(lock_file)
        error = LeechtopDownloader::Client::DownloadError.new("Mock failure")
        allow(LeechtopDownloader::Client).to receive(:download_from_html).and_raise(error)

        expect do
          cli.download(url)
        end.to output(/Error downloading #{Regexp.escape(url)}: Mock failure/).to_stdout

        expect(FileUtils).to have_received(:rm_f).with("downloads/example.bin.lock")
      end
    end

    context "when a non-leechtop URL is provided" do
      let(:page_url) { "https://example.com/some_manga" }

      it "extracts links from the page and downloads them sequentially" do
        extracted_links = ["https://leechtop.com/file1.zip", "https://leechtop.com/file2.zip"]
        allow(LeechtopDownloader::Client).to receive(:extract_page_links).with(page_url).and_return(extracted_links)
        allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(extracted_links[0]).and_return(
          { html: "<html>1</html>", filename: "example.bin" }
        )
        allow(LeechtopDownloader::Client).to receive(:download_from_html).with("<html>1</html>").and_return(io)
        allow(LeechtopDownloader::Client).to receive(:fetch_metadata).with(extracted_links[1]).and_return(
          { html: "<html>2</html>", filename: "example.bin" }
        )
        allow(LeechtopDownloader::Client).to receive(:download_from_html).with("<html>2</html>").and_return(io)

        expected_output = /
          Fetching\ links\ from:\ #{Regexp.escape(page_url)}.*
          Found\ 2\ leechtop\.com\ link\(s\)\.\ Downloading\.\.\..*
          Successfully\ downloaded\ example\.bin\ \(8\ bytes\).*
          Successfully\ downloaded\ example\.bin\ \(8\ bytes\)
        /mx

        expect do
          cli.download(page_url)
        end.to output(expected_output).to_stdout

        expect(LeechtopDownloader::Client).to have_received(:extract_page_links).with(page_url)
        expect(LeechtopDownloader::Client).to have_received(:fetch_metadata).with(extracted_links[0])
        expect(LeechtopDownloader::Client).to have_received(:fetch_metadata).with(extracted_links[1])
        expect(LeechtopDownloader::Client).to have_received(:download_from_html).with("<html>1</html>")
        expect(LeechtopDownloader::Client).to have_received(:download_from_html).with("<html>2</html>")
        expect(LeechtopDownloader::FileManager).to have_received(:save_stream).with(io, "example.bin").twice
      end

      it "prints a message if no leechtop links are found on the page" do
        allow(LeechtopDownloader::Client).to receive(:extract_page_links).with(page_url).and_return([])

        expected_output = /
          Fetching\ links\ from:\ #{Regexp.escape(page_url)}.*
          No\ leechtop\.com\ links\ found\ on\ #{Regexp.escape(page_url)}
        /mx

        expect do
          cli.download(page_url)
        end.to output(expected_output).to_stdout
      end
    end

    context "when a text file containing links is provided" do
      it "reads the file and processes each non-empty line as a URL" do
        file_path = "links.txt"
        first_url = "https://leechtop.com/file_a.zip"
        second_url = "https://leechtop.com/file_b.zip"

        allow(File).to receive(:file?).and_call_original
        allow(File).to receive(:file?).with(file_path).and_return(true)
        allow(File).to receive(:readlines).with(file_path, chomp: true).and_return([first_url, "", "  ", second_url])
        allow(cli).to receive(:process_url)

        cli.download(file_path)

        expect(cli).to have_received(:process_url).with(first_url, skip_existing: true)
        expect(cli).to have_received(:process_url).with(second_url, skip_existing: true)
        expect(cli).to have_received(:process_url).exactly(2).times
      end
    end
  end
end
