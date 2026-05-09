# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "down"
require "faraday"
require "nokogiri"
require "json"

module LeechtopDownloader
  # Client handles the network requests to Leechtop.
  class Client
    extend T::Sig

    class DownloadError < Error; end

    # LT-REQ-002, LT-REQ-003
    sig { params(url: String).returns(T.any(IO, StringIO, Tempfile)) }
    def self.download(url)
      direct_url = extract_direct_url(url)
      Down.download(direct_url)
    rescue Down::NotFound
      raise DownloadError, "The file could not be found on the host server (404 Not Found). It may have been deleted."
    rescue Down::ClientError, Down::ServerError => e
      raise DownloadError, "The host server rejected the download: #{e.message}"
    rescue StandardError => e
      raise DownloadError, "Network or extraction failure: #{e.message}"
    end

    sig { params(url: String).returns(String) }
    def self.extract_direct_url(url)
      html = fetch_html(url)
      tokens = parse_tokens(html)
      fetch_ajax_direct_link(tokens)
    end

    sig { params(url: String).returns(String) }
    def self.fetch_html(url)
      response = Faraday.new.get(url)
      raise "Failed to load page: HTTP #{response.status}" unless response.status == 200

      response.body
    end

    sig { params(html: String).returns(T::Hash[Symbol, String]) }
    def self.parse_tokens(html)
      document = Nokogiri::HTML(html)

      button = document.at_css(".go-download-direct")
      raise "Could not find download button in HTML" unless button

      nonce_match = html.match(/"nonce":"([^"]+)"/)
      raise "Could not extract nonce from page" unless nonce_match

      {
        p: T.must(button["data-p"]),
        mb: T.must(button["data-mb"]),
        nonce: T.must(nonce_match[1])
      }
    end

    sig { params(tokens: T::Hash[Symbol, String]).returns(String) }
    def self.fetch_ajax_direct_link(tokens)
      ajax_url = "https://leechtop.com/wp-admin/admin-ajax.php"
      body = URI.encode_www_form({ action: "z_do_ajax", _action: "directDownload" }.merge(tokens))
      post_response = Faraday.new.post(ajax_url, body)

      raise "AJAX request failed: HTTP #{post_response.status}" unless post_response.status == 200

      parse_ajax_response(post_response.body)
    end

    sig { params(body: String).returns(String) }
    def self.parse_ajax_response(body)
      json = JSON.parse(body)
      direct_link = json["mes"]

      raise "Server rejected download request: #{json}" if direct_link == "no" || direct_link.nil?

      direct_link
    end

    sig { params(url: String).returns(T::Array[String]) }
    def self.extract_page_links(url)
      html = fetch_html(url)
      document = Nokogiri::HTML(html)

      document.css("a").filter_map do |a|
        href = a["href"]
        href if href&.match?(%r{^https?://(?:www\.)?leechtop\.com/})
      end
    end
  end
end
