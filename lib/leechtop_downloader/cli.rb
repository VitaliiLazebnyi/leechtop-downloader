# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "thor"

module LeechtopDownloader
  # CLI is the Thor application for handling commands.
  class CLI < Thor
    extend T::Sig

    def self.exit_on_failure?
      true
    end

    desc "download URL...", "Download one or more URLs from leechtop.com"
    # LT-REQ-001, LT-REQ-002
    def download(*urls)
      if urls.empty?
        puts "Error: You must provide at least one URL."
        exit 1
      end

      urls.each do |url|
        download_single(url)
      end
    end

    private

    sig { params(url: String).void }
    def download_single(url)
      puts "Downloading: #{url}"
      puts "Bypassing countdown and extracting direct link..."
      begin
        io = Client.download(url)
        filename = extract_filename(url, io)
        bytes = FileManager.save_stream(io, filename)
        puts "Successfully downloaded #{filename} (#{bytes} bytes)"
      rescue Error => e
        puts "Error downloading #{url}: #{e.message}"
      end
    end

    # Helper method to extract filename, falling back to a default if necessary
    sig { params(_url: String, io: T.any(IO, StringIO, Tempfile)).returns(String) }
    def extract_filename(_url, io)
      if io.respond_to?(:original_filename) && T.unsafe(io).original_filename
        T.cast(T.unsafe(io).original_filename, String)
      else
        # Fallback metric timestamp based filename if no headers present
        "leechtop_#{Time.now.utc.to_i}.bin"
      end
    end
  end
end
