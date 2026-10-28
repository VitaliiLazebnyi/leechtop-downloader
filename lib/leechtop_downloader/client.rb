# typed: strict
# frozen_string_literal: true

require 'down'
require 'faraday'
require 'json'
require 'nokogiri'
require 'sorbet-runtime'

require_relative 'client/download_error'

module LeechtopDownloader
  # Client handles the network requests to Leechtop.
  class Client
    extend T::Sig

    # The endpoint that hands out the direct link of a file.
    AJAX_URL = 'https://leechtop.com/wp-admin/admin-ajax.php'
    # Timeouts (in seconds) of every page request.
    REQUEST_OPTIONS = T.let({ open_timeout: 10, timeout: 60 }.freeze, T::Hash[Symbol, Integer])
    # Matches the links that point to a file page on leechtop.com.
    LEECHTOP_URL = %r{\Ahttps?://(?:www\.)?leechtop\.com/}
    # Pages are parsed as UTF-8, whatever charset they declare.
    HTML_ENCODING = 'UTF-8'
    private_constant :AJAX_URL, :REQUEST_OPTIONS, :HTML_ENCODING
    public_constant :LEECHTOP_URL

    # LT-REQ-002, LT-REQ-003
    # Downloads a file from the given direct URL.
    # @param url [String] The URL to download.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    sig { params(url: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download(url)
      translate_errors { download_direct(extract_direct_url(url)) }
    end

    # Downloads a file by extracting the direct link from the page HTML.
    # @param html [String] The HTML content of the page.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    sig { params(html: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download_from_html(html)
      translate_errors { download_direct(fetch_ajax_direct_link(parse_tokens(html))) }
    end

    # Fetches the HTML and metadata (filename) from a given URL.
    # @param url [String] The URL to fetch.
    # @return [Hash<Symbol, String>] The parsed metadata including html and filename.
    sig { params(url: String).returns(T::Hash[Symbol, String]) }
    def self.fetch_metadata(url)
      html = fetch_html(url)
      title = parse_html(html).at_css('h4.mb-2')
      { html: html, filename: title ? title.text.strip : '' }
    end

    # Extracts the direct URL from the page HTML via AJAX.
    # @param url [String] The URL to fetch.
    # @return [String] The extracted direct URL.
    sig { params(url: String).returns(String) }
    def self.extract_direct_url(url)
      fetch_ajax_direct_link(parse_tokens(fetch_html(url)))
    end

    # Fetches the raw HTML content from a URL.
    # @param url [String] The URL to fetch.
    # @return [String] The HTML content.
    # @raise [DownloadError] when the page cannot be loaded.
    sig { params(url: String).returns(String) }
    def self.fetch_html(url)
      request('Failed to load page') { |connection| connection.get(url) }
    end

    # Parses the necessary tokens from the given HTML string.
    # @param html [String] The HTML content.
    # @return [Hash<Symbol, String>] The extracted tokens.
    sig { params(html: String).returns(T::Hash[Symbol, String]) }
    def self.parse_tokens(html)
      { **button_tokens(parse_html(html)), nonce: page_nonce(html) }
    end

    # Submits the parsed tokens via AJAX to obtain the direct download link.
    # @param tokens [Hash<Symbol, String>] The extracted tokens.
    # @return [String] The direct download link.
    sig { params(tokens: T::Hash[Symbol, String]).returns(String) }
    def self.fetch_ajax_direct_link(tokens)
      # Faraday sends a Hash body form-encoded.
      body = { action: 'z_do_ajax', _action: 'directDownload' }.merge(tokens)
      parse_ajax_response(request('AJAX request failed') { |connection| connection.post(AJAX_URL, body) })
    end

    # Parses the AJAX response to extract the direct link.
    # @param body [String] The JSON string.
    # @return [String] The extracted direct download link.
    sig { params(body: String).returns(String) }
    def self.parse_ajax_response(body)
      json = JSON.parse(body)
      direct_link = json['mes']
      return direct_link if direct_link.instance_of?(String) && !direct_link.eql?('no')

      raise "Server rejected download request: #{json}"
    end

    # Extracts all Leechtop links from a given page HTML.
    # @param url [String] The URL to fetch.
    # @return [Array<String>] The extracted URLs.
    sig { params(url: String).returns(T::Array[String]) }
    def self.extract_page_links(url)
      parse_html(fetch_html(url)).css('a').filter_map do |anchor|
        href = anchor['href'].to_s
        href if href.match?(LEECHTOP_URL)
      end
    end

    # Parses an HTML document as UTF-8.
    # @param html [String] The HTML content.
    # @return [Nokogiri::HTML4::Document] The parsed document.
    sig { params(html: String).returns(Nokogiri::HTML4::Document) }
    def self.parse_html(html)
      Nokogiri::HTML(html, nil, HTML_ENCODING)
    end

    # Reads the tokens of the download button.
    # @param document [Nokogiri::HTML4::Document] The parsed page.
    # @return [Hash<Symbol, String>] The +p+ and +mb+ tokens.
    sig { params(document: Nokogiri::HTML4::Document).returns(T::Hash[Symbol, String]) }
    def self.button_tokens(document)
      button = document.at_css('.go-download-direct')
      raise 'Could not find download button in HTML' unless button

      tokens = { p: button['data-p'], mb: button['data-mb'] }
      raise 'Could not find the tokens of the download button' if tokens.value?(nil)

      tokens
    end

    # Reads the nonce the page passes to its scripts.
    # @param html [String] The HTML content.
    # @return [String] The nonce.
    sig { params(html: String).returns(String) }
    def self.page_nonce(html)
      html[/"nonce":"([^"]+)"/, 1] || raise('Could not extract nonce from page')
    end

    # Sends one request with the page timeouts and returns the body of its successful response.
    # @param failure [String] What failed, the start of the error message.
    # @yieldparam connection [Faraday::Connection] The connection to send the request with.
    # @yieldreturn [Faraday::Response] The response of the request.
    # @return [String] The body of the response.
    # @raise [DownloadError] when the server cannot be reached or does not answer with HTTP 200.
    sig do
      params(failure: String, blk: T.proc.params(connection: Faraday::Connection).returns(Faraday::Response))
        .returns(String)
    end
    def self.request(failure, &blk)
      response = yield(Faraday.new(request: REQUEST_OPTIONS))
      successful(failure, response.status) { response.body }
    rescue Faraday::Error => error
      raise DownloadError, "#{failure}: #{error}"
    end

    # Returns the body of a response if its status is HTTP 200.
    # @param failure [String] What failed, the start of the error message.
    # @param status [Integer] The HTTP status of the response.
    # @yieldreturn [String] The body of the response.
    # @return [String] The body of the response.
    # @raise [DownloadError] when the status is not HTTP 200.
    sig { params(failure: String, status: Integer, blk: T.proc.returns(String)).returns(String) }
    def self.successful(failure, status, &blk)
      status == 200 ? yield : raise(DownloadError, "#{failure}: HTTP #{status}")
    end

    # Downloads the file behind a direct link.
    # @param direct_url [String] The direct link.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    sig { params(direct_url: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download_direct(direct_url)
      Down.download(direct_url, open_timeout: 10, read_timeout: 60)
    end

    # Runs a download and reports every failure as a DownloadError with a readable message.
    # @yieldreturn [IO, StringIO, Tempfile] The downloaded stream.
    # @return [IO, StringIO, Tempfile] The downloaded stream.
    # @raise [DownloadError] when the download fails for any reason.
    sig { params(blk: T.proc.returns(T.any(IO, StringIO, Tempfile))).returns(T.any(IO, StringIO, Tempfile)) }
    def self.translate_errors(&blk)
      yield
    rescue StandardError => error
      raise DownloadError, DownloadError.describe(error)
    end

    private_class_method :parse_html, :button_tokens, :page_nonce, :request, :successful, :download_direct,
                         :translate_errors
  end
end
