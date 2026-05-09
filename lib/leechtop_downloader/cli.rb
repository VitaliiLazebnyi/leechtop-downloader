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
        process_url(url)
      end
    end

    private

    sig { params(url: String).void }
    def process_url(url)
      if url.match?(%r{^https?://(?:www\.)?leechtop\.com/})
        download_single(url)
      else
        extract_and_download_links(url)
      end
    end

    sig { params(url: String).void }
    def extract_and_download_links(url)
      puts "Fetching links from: #{url}"
      links = Client.extract_page_links(url)
      if links.empty?
        puts "No leechtop.com links found on #{url}"
      else
        puts "Found #{links.size} leechtop.com link(s). Downloading..."
        links.each { |link| download_single(link) }
      end
    end

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
