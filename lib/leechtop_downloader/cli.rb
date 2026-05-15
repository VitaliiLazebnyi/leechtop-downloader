# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "thor"
require "digest"
require "fileutils"
require "tmpdir"
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
    method_option :destination, type: :string, default: ".", desc: "Destination folder for downloaded files"
    desc "download URL_OR_FILE...", "Download one or more URLs (or a text file with links) from leechtop.com"
    # LT-REQ-001, LT-REQ-002
    def download(*urls)
      if urls.empty?
        puts "Error: You must provide at least one URL or file path."
        exit 1
      end

      with_app_lock do
        skip_existing = options.fetch(:skip_existing, true)
        destination = options.fetch(:destination, ".")

        urls.each { |arg| process_argument(arg, skip_existing, destination) }
      end
    end

    private

    sig { params(arg: String, skip_existing: T::Boolean, destination: String).void }
    def process_argument(arg, skip_existing, destination)
      if File.file?(arg)
        File.readlines(arg, chomp: true).each do |line|
          link = line.strip
          process_url(link, skip_existing: skip_existing, destination: destination) unless link.empty?
        end
      else
        process_url(arg, skip_existing: skip_existing, destination: destination)
      end
    end

    sig { params(url: String, skip_existing: T::Boolean, destination: String).void }
    def process_url(url, skip_existing: true, destination: ".")
      if url.match?(%r{^https?://(?:www\.)?leechtop\.com/})
        download_single(url, skip_existing: skip_existing, destination: destination)
      else
        extract_and_download_links(url, skip_existing: skip_existing, destination: destination)
      end
    end

    sig { params(url: String, skip_existing: T::Boolean, destination: String).void }
    def extract_and_download_links(url, skip_existing: true, destination: ".")
      puts "Fetching links from: #{url}"
      links = Client.extract_page_links(url)
      if links.empty?
        puts "No leechtop.com links found on #{url}"
      else
        puts "Found #{links.size} leechtop.com link(s). Downloading..."
        links.each { |link| download_single(link, skip_existing: skip_existing, destination: destination) }
      end
    end

    sig { params(url: String, skip_existing: T::Boolean, destination: String).void }
    def download_single(url, skip_existing: true, destination: ".")
      puts "Downloading: #{url}\nBypassing countdown and extracting direct link..."
      metadata = Client.fetch_metadata(url)
      return if skip_download?(metadata.fetch(:filename), skip_existing, destination)

      download_with_lock(url, metadata, metadata.fetch(:filename), destination)
    rescue Error => e
      puts "Error downloading #{url}: #{e.message}"
    end

    sig { params(url: String, filename_hint: String, destination: String, blk: T.proc.void).void }
    def with_lock(url, filename_hint, destination, &blk)
      lock_path = lock_path_for(url, filename_hint, destination)
      acquired = acquire_lock(lock_path)
      return skip_locked(filename_hint) unless acquired

      blk.call
    ensure
      FileUtils.rm_f(lock_path) if acquired
    end

    sig { params(url: String, metadata: T::Hash[Symbol, String], filename_hint: String, destination: String).void }
    def download_with_lock(url, metadata, filename_hint, destination)
      FileUtils.mkdir_p(destination)
      with_lock(url, filename_hint, destination) do
        perform_download(url, metadata, filename_hint, destination)
      end
    end

    sig { params(url: String, metadata: T::Hash[Symbol, String], filename_hint: String, destination: String).void }
    def perform_download(url, metadata, filename_hint, destination)
      display_name = filename_hint.empty? ? "unknown" : filename_hint
      puts "Starting download of file: #{display_name}..."
      io = Client.download_from_html(metadata.fetch(:html))
      filename = extract_filename(url, io, filename_hint)
      bytes_written, resolved_filename = FileManager.save_stream(io, filename, destination)
      puts "Successfully downloaded #{resolved_filename} (#{bytes_written} bytes)"
    end

    # Helper method to extract filename, falling back to a default if necessary
    sig { params(_url: String, io: T.any(IO, StringIO, Tempfile), filename_hint: String).returns(String) }
    def extract_filename(_url, io, filename_hint = "")
      if io.respond_to?(:original_filename) && T.unsafe(io).original_filename
        name = T.cast(T.unsafe(io).original_filename, String)
        fix_encoding(name)
      elsif !filename_hint.empty?
        filename_hint
      else
        # Fallback metric timestamp based filename if no headers present
        "leechtop_#{Time.now.utc.to_i}.bin"
      end
    end
  end
end
