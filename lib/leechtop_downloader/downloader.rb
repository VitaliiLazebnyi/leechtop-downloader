# typed: strict
# frozen_string_literal: true

require 'down'
require 'fileutils'
require 'sorbet-runtime'

module LeechtopDownloader
  # Downloads leechtop.com files, either from their page URL or from every leechtop.com link on another page.
  class Downloader
    extend T::Sig

    # The URLs an argument stands for: the non-empty lines of the file it names (read as UTF-8, whatever the
    # locale), or the argument itself.
    # @param arg [String] A URL, or the path of a text file with one URL per line.
    # @return [Array<String>] The URLs.
    sig { params(arg: String).returns(T::Array[String]) }
    def self.urls_in(arg)
      return [arg] unless File.file?(arg)

      File.readlines(arg, chomp: true, encoding: Encoding::UTF_8).filter_map do |line|
        link = line.strip
        link unless link.empty?
      end
    end

    # The HTML of a file page and the (sanitized) name of the file it shows.
    # @param url [String] The URL of the file page.
    # @return [Array(String, String)] The HTML and the file name.
    sig { params(url: String).returns([String, String]) }
    def self.page(url)
      metadata = Client.fetch_metadata(url)
      [metadata.fetch(:html), Filename.sanitize(metadata.fetch(:filename))]
    end

    # @param skip_existing [Boolean] Whether to skip files that already exist in the destination.
    # @param destination [String] The download destination directory.
    sig { params(skip_existing: T::Boolean, destination: String).void }
    def initialize(skip_existing:, destination:)
      @skip_existing = skip_existing
      @destination = destination
    end

    # Processes a single CLI argument: a URL, or a text file with one URL per line.
    # @param arg [String] The argument string.
    sig { params(arg: String).void }
    def process_argument(arg)
      Downloader.urls_in(arg).each { |url| process(url) }
    end

    # LT-REQ-002: downloads a leechtop.com file page, or every leechtop.com link found on any other page.
    # Failures are printed; they never stop the downloads of the other URLs.
    # @param url [String] The URL string.
    sig { params(url: String).void }
    def process(url)
      url.match?(Client::LEECHTOP_URL) ? download(url) : download_links(url)
    end

    private

    # Downloads every leechtop.com link found on a page.
    # @param url [String] The URL of the page.
    sig { params(url: String).void }
    def download_links(url)
      puts "Fetching links from: #{url}"
      download_all(Client.extract_page_links(url), url)
    rescue Error => error
      puts "Error fetching links from #{url}: #{error.message}"
    end

    # Downloads the leechtop.com links found on a page.
    # @param links [Array<String>] The links.
    # @param page_url [String] The URL of the page they were found on.
    sig { params(links: T::Array[String], page_url: String).void }
    def download_all(links, page_url)
      return puts("No leechtop.com links found on #{page_url}") if links.empty?

      puts "Found #{links.size} leechtop.com link(s). Downloading..."
      links.each { |link| download(link) }
    end

    # Downloads a single file page.
    # @param url [String] The URL of the file page.
    sig { params(url: String).void }
    def download(url)
      puts "Downloading: #{url}\nBypassing countdown and extracting direct link..."
      html, filename = Downloader.page(url)
      save(url, html, filename) unless skip?(filename)
    rescue Error => error
      puts "Error downloading #{url}: #{error.message}"
    end

    # Checks if a download should be skipped because the file already exists.
    # @param filename [String] The name of the file, or an empty string when it is not known.
    # @return [Boolean] true if the download should be skipped, false otherwise.
    sig { params(filename: String).returns(T::Boolean) }
    def skip?(filename)
      return false unless @skip_existing && !filename.empty? && File.exist?(File.join(@destination, filename))

      puts "File #{filename} already exists. Skipping."
      true
    end

    # Downloads the file of a page while holding its download lock.
    # @param url [String] The URL of the file page.
    # @param html [String] The HTML of the file page.
    # @param filename [String] The name of the file shown on the page.
    sig { params(url: String, html: String, filename: String).void }
    def save(url, html, filename)
      FileUtils.mkdir_p(@destination)
      DownloadLock.new(url:, filename:, directory: @destination).hold { transfer(html, filename) }
    end

    # Downloads the file of a page into the destination directory.
    # @param html [String] The HTML of the file page.
    # @param filename [String] The name of the file shown on the page.
    sig { params(html: String, filename: String).void }
    def transfer(html, filename)
      puts "Starting download of file: #{filename.empty? ? 'unknown' : filename}..."
      io = Client.download_from_html(html)
      bytes_written, saved_name = FileManager.save_stream(io, Filename.for_download(io, filename), @destination)
      puts "Successfully downloaded #{saved_name} (#{bytes_written} bytes)"
    end
  end
end
