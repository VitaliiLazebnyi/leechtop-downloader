# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "thor"
require "digest"
require "fileutils"
require_relative "cli_helpers"

module LeechtopDownloader
  # CLI is the Thor application for handling commands.
  class CLI < Thor
    extend T::Sig
    include CLIHelpers

    def self.exit_on_failure?
      true
    end

    method_option :skip_existing, type: :boolean, default: true, desc: "Skip downloading already existing files"
    desc "download URL...", "Download one or more URLs from leechtop.com"
    # LT-REQ-001, LT-REQ-002
    def download(*urls)
      if urls.empty?
        puts "Error: You must provide at least one URL."
        exit 1
      end

      skip_existing = options.fetch(:skip_existing, true)

      urls.each do |url|
        process_url(url, skip_existing: skip_existing)
      end
    end

    private

    sig { params(url: String, skip_existing: T::Boolean).void }
    def process_url(url, skip_existing: true)
      if url.match?(%r{^https?://(?:www\.)?leechtop\.com/})
        download_single(url, skip_existing: skip_existing)
      else
        extract_and_download_links(url, skip_existing: skip_existing)
      end
    end

    sig { params(url: String, skip_existing: T::Boolean).void }
    def extract_and_download_links(url, skip_existing: true)
      puts "Fetching links from: #{url}"
      links = Client.extract_page_links(url)
      if links.empty?
        puts "No leechtop.com links found on #{url}"
      else
        puts "Found #{links.size} leechtop.com link(s). Downloading..."
        links.each { |link| download_single(link, skip_existing: skip_existing) }
      end
    end

    sig { params(url: String, skip_existing: T::Boolean).void }
    def download_single(url, skip_existing: true)
      puts "Downloading: #{url}\nBypassing countdown and extracting direct link..."
      metadata = Client.fetch_metadata(url)
      return if skip_download?(metadata.fetch(:filename), skip_existing)

      download_with_lock(url, metadata, metadata.fetch(:filename))
    rescue Error => e
      puts "Error downloading #{url}: #{e.message}"
    end

    sig { params(url: String, filename_hint: String, blk: T.proc.void).void }
    def with_lock(url, filename_hint, &blk)
      lock_path = lock_path_for(url, filename_hint)
      acquired = acquire_lock(lock_path)
      return skip_locked(filename_hint) unless acquired

      blk.call
    ensure
      FileUtils.rm_f(lock_path) if acquired
    end

    sig { params(url: String, metadata: T::Hash[Symbol, String], filename_hint: String).void }
    def download_with_lock(url, metadata, filename_hint)
      FileUtils.mkdir_p("downloads")
      with_lock(url, filename_hint) do
        perform_download(url, metadata, filename_hint)
      end
    end

    sig { params(url: String, metadata: T::Hash[Symbol, String], filename_hint: String).void }
    def perform_download(url, metadata, filename_hint)
      io = Client.download_from_html(metadata.fetch(:html))
      filename = extract_filename(url, io, filename_hint)
      bytes = FileManager.save_stream(io, filename)
      puts "Successfully downloaded #{filename} (#{bytes} bytes)"
    end

    # Helper method to extract filename, falling back to a default if necessary
    sig { params(_url: String, io: T.any(IO, StringIO, Tempfile), filename_hint: String).returns(String) }
    def extract_filename(_url, io, filename_hint = "")
      if io.respond_to?(:original_filename) && T.unsafe(io).original_filename
        T.cast(T.unsafe(io).original_filename, String)
      elsif !filename_hint.empty?
        filename_hint
      else
        # Fallback metric timestamp based filename if no headers present
        "leechtop_#{Time.now.utc.to_i}.bin"
      end
    end
  end
end
