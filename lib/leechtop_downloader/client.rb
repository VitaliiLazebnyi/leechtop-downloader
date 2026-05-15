# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'down'
require 'faraday'
require 'nokogiri'
require 'json'

module LeechtopDownloader
  # Client handles the network requests to Leechtop.
  class Client
    extend T::Sig

    # Error class for download-specific errors.
    class DownloadError < Error; end

    # LT-REQ-002, LT-REQ-003
    # Downloads a file from the given direct URL.
    # @param url [String] The URL to download.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    sig { params(url: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download(url)
      direct_url = extract_direct_url(url)
      Down.download(direct_url, open_timeout: 10, read_timeout: 60)
    rescue Down::NotFound
      raise DownloadError, 'The file could not be found on the host server (404 Not Found). It may have been deleted.'
    rescue Down::ClientError, Down::ServerError => e
      raise DownloadError, "The host server rejected the download: #{e.message}"
    rescue StandardError => e
      raise DownloadError, "Network or extraction failure: #{e.message}"
    end

    # Downloads a file by extracting the direct link from the page HTML.
    # @param html [String] The HTML content of the page.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    sig { params(html: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download_from_html(html)
      tokens = parse_tokens(html)
      direct_url = fetch_ajax_direct_link(tokens)
      Down.download(direct_url, open_timeout: 10, read_timeout: 60)
    rescue Down::NotFound
      raise DownloadError, 'The file could not be found on the host server (404 Not Found). It may have been deleted.'
    rescue Down::ClientError, Down::ServerError => e
      raise DownloadError, "The host server rejected the download: #{e.message}"
    rescue StandardError => e
      raise DownloadError, "Network or extraction failure: #{e.message}"
    end

    # Fetches the HTML and metadata (filename) from a given URL.
    # @param url [String] The URL to fetch.
    # @return [Hash<Symbol, String>] The parsed metadata including html and filename.
    sig { params(url: String).returns(T::Hash[Symbol, String]) }
    def self.fetch_metadata(url)
      html = fetch_html(url)
      document = Nokogiri::HTML(html, nil, 'UTF-8')
      h4 = document.at_css('h4.mb-2')
      filename = h4&.text&.strip || ''

      { html: html, filename: filename }
    end

    # Extracts the direct URL from the page HTML via AJAX.
    # @param url [String] The URL to fetch.
    # @return [String] The extracted direct URL.
    sig { params(url: String).returns(String) }
    def self.extract_direct_url(url)
      html = fetch_html(url)
      tokens = parse_tokens(html)
      fetch_ajax_direct_link(tokens)
    end

    # Fetches the raw HTML content from a URL.
    # @param url [String] The URL to fetch.
    # @return [String] The HTML content.
    sig { params(url: String).returns(String) }
    def self.fetch_html(url)
      response = Faraday.new(request: { open_timeout: 10, timeout: 60 }).get(url)
      raise "Failed to load page: HTTP #{response.status}" unless response.status == 200

      response.body
    end

    # Parses the necessary tokens from the given HTML string.
    # @param html [String] The HTML content.
    # @return [Hash<Symbol, String>] The extracted tokens.
    sig { params(html: String).returns(T::Hash[Symbol, String]) }
    def self.parse_tokens(html)
      document = Nokogiri::HTML(html, nil, 'UTF-8')

      button = document.at_css('.go-download-direct')
      raise 'Could not find download button in HTML' unless button

      nonce_match = html.match(/"nonce":"([^"]+)"/)
      raise 'Could not extract nonce from page' unless nonce_match

      {
        p: T.must(button['data-p']),
        mb: T.must(button['data-mb']),
        nonce: T.must(nonce_match[1])
      }
    end

    # Submits the parsed tokens via AJAX to obtain the direct download link.
    # @param tokens [Hash<Symbol, String>] The extracted tokens.
    # @return [String] The direct download link.
    sig { params(tokens: T::Hash[Symbol, String]).returns(String) }
    def self.fetch_ajax_direct_link(tokens)
      ajax_url = 'https://leechtop.com/wp-admin/admin-ajax.php'
      body = URI.encode_www_form({ action: 'z_do_ajax', _action: 'directDownload' }.merge(tokens))
      post_response = Faraday.new(request: { open_timeout: 10, timeout: 60 }).post(ajax_url, body)

      raise "AJAX request failed: HTTP #{post_response.status}" unless post_response.status == 200

      parse_ajax_response(post_response.body)
    end

    # Parses the AJAX response to extract the direct link.
    # @param body [String] The JSON string.
    # @return [String] The extracted direct download link.
    sig { params(body: String).returns(String) }
    def self.parse_ajax_response(body)
      json = JSON.parse(body)
      direct_link = json['mes']

      raise "Server rejected download request: #{json}" if direct_link == 'no' || direct_link.nil?

      direct_link
    end

    # Extracts all Leechtop links from a given page HTML.
    # @param url [String] The URL to fetch.
    # @return [Array<String>] The extracted URLs.
    sig { params(url: String).returns(T::Array[String]) }
    def self.extract_page_links(url)
      html = fetch_html(url)
      document = Nokogiri::HTML(html, nil, 'UTF-8')

      document.css('a').filter_map do |a|
        href = a['href']
        href if href&.match?(%r{^https?://(?:www\.)?leechtop\.com/})
      end
    end
  end
end
