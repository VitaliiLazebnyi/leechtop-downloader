# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::Client do
  let(:url) { 'https://leechtop.com/test.bin' }
  let(:direct_url) { 'https://actual.link/file.rar' }
  let(:mock_conn) { instance_double(Faraday::Connection) }

  before do
    allow(Faraday).to receive(:new).and_return(mock_conn)
  end

  describe '.download' do
    before do
      allow(described_class).to receive(:extract_direct_url).with(url).and_return(direct_url)
    end

    it 'LT-REQ-002: successfully downloads from a given URL after extracting direct link' do
      mock_io = StringIO.new('data')
      allow(Down).to receive(:download).with(direct_url, open_timeout: 10, read_timeout: 60).and_return(mock_io)

      result = described_class.download(url)
      expect(result).to eq(mock_io)
    end

    it 'raises a DownloadError when the file is not found (404)' do
      allow(Down).to receive(:download).with(direct_url, open_timeout: 10,
                                                         read_timeout: 60)
                                       .and_raise(Down::NotFound.new('404 Not Found'))

      expect do
        described_class.download(url)
      end.to raise_error(LeechtopDownloader::Client::DownloadError, /The file could not be found on the host server/)
    end

    it 'raises a DownloadError when the server rejects the download' do
      allow(Down).to receive(:download).with(direct_url, open_timeout: 10,
                                                         read_timeout: 60)
                                       .and_raise(Down::ServerError.new('500 Internal Server Error'))

      expect do
        described_class.download(url)
      end.to raise_error(LeechtopDownloader::Client::DownloadError, /The host server rejected the download/)
    end

    it 'raises a DownloadError for general extraction or network failures' do
      allow(Down).to receive(:download).with(direct_url, open_timeout: 10,
                                                         read_timeout: 60)
                                       .and_raise(StandardError.new('Network failure'))

      expect do
        described_class.download(url)
      end.to raise_error(LeechtopDownloader::Client::DownloadError, /Network or extraction failure: Network failure/)
    end
  end

  describe '.download_from_html' do
    let(:html) do
      "<html><a class='go-download-direct' data-p='1' data-mb='2'></a>" \
        '<script>var zing = {"nonce":"abc"};</script></html>'
    end

    before do
      post_response = instance_double(Faraday::Response, status: 200, body: '{"mes":"https://actual.link/file.rar"}')
      allow(mock_conn).to receive(:post).and_return(post_response)
    end

    it 'raises a DownloadError when the file is not found (404)' do
      allow(Down).to receive(:download).and_raise(Down::NotFound.new('404 Not Found'))
      expect do
        described_class.download_from_html(html)
      end.to raise_error(LeechtopDownloader::Client::DownloadError,
                         /The file could not be found on the host server/)
    end

    it 'raises a DownloadError when the server rejects the download' do
      allow(Down).to receive(:download).and_raise(Down::ServerError.new('500 Internal Server Error'))
      expect do
        described_class.download_from_html(html)
      end.to raise_error(LeechtopDownloader::Client::DownloadError,
                         /The host server rejected the download/)
    end

    it 'raises a DownloadError for general extraction or network failures' do
      allow(Down).to receive(:download).and_raise(StandardError.new('Network failure'))
      expect do
        described_class.download_from_html(html)
      end.to raise_error(LeechtopDownloader::Client::DownloadError,
                         /Network or extraction failure/)
    end
  end

  describe '.fetch_metadata' do
    it 'extracts the HTML and filename' do
      html = "<html><h4 class='mb-2'>MyFile.zip</h4></html>"
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      result = described_class.fetch_metadata(url)
      expect(result).to eq({ html: html, filename: 'MyFile.zip' })
    end

    it 'returns an empty string for filename if h4 element is missing' do
      html = '<html><body>No h4 here</body></html>'
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      result = described_class.fetch_metadata(url)
      expect(result).to eq({ html: html, filename: '' })
    end
  end

  describe '.extract_direct_url' do
    let(:html) do
      <<~HTML
        <html>
          <body>
            <a class="go-download-direct" data-p="123" data-mb="456">Download</a>
            <script>var zing = {"nonce":"abcde"};</script>
          </body>
        </html>
      HTML
    end

    it 'extracts the tokens and fetches the direct url via AJAX' do
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      post_response = instance_double(Faraday::Response, status: 200, body: '{"mes":"https://actual.link/file.rar"}')
      allow(mock_conn).to receive(:post).with('https://leechtop.com/wp-admin/admin-ajax.php',
                                              anything).and_return(post_response)

      result = described_class.extract_direct_url(url)
      expect(result).to eq('https://actual.link/file.rar')
    end

    it 'raises an error if the initial page load fails' do
      get_response = instance_double(Faraday::Response, status: 500)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      expect { described_class.extract_direct_url(url) }.to raise_error(/Failed to load page/)
    end

    it 'raises an error if the download button is missing' do
      get_response = instance_double(Faraday::Response, status: 200, body: '<html></html>')
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      expect { described_class.extract_direct_url(url) }.to raise_error(/Could not find download button/)
    end

    it 'raises an error if the nonce is missing' do
      bad_html = '<html><a class="go-download-direct" data-p="1" data-mb="2"></a></html>'
      get_response = instance_double(Faraday::Response, status: 200, body: bad_html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      expect { described_class.extract_direct_url(url) }.to raise_error(/Could not extract nonce/)
    end

    it 'raises an error if the AJAX request fails' do
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      post_response = instance_double(Faraday::Response, status: 500)
      allow(mock_conn).to receive(:post).with('https://leechtop.com/wp-admin/admin-ajax.php',
                                              anything).and_return(post_response)

      expect { described_class.extract_direct_url(url) }.to raise_error(/AJAX request failed/)
    end

    it 'raises an error if the server rejects the download' do
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(url).and_return(get_response)

      post_response = instance_double(Faraday::Response, status: 200, body: '{"mes":"no"}')
      allow(mock_conn).to receive(:post).with('https://leechtop.com/wp-admin/admin-ajax.php',
                                              anything).and_return(post_response)

      expect { described_class.extract_direct_url(url) }.to raise_error(/Server rejected download request/)
    end
  end

  describe '.extract_page_links' do
    let(:page_url) { 'https://example.com/some_page' }

    it 'extracts all leechtop.com links from a given HTML page and ignores tags without href' do
      html = <<~HTML
        <html>
          <body>
            <a href="https://leechtop.com/file1/">File 1</a>
            <a href="http://leechtop.com/file2/">File 2</a>
            <a href="https://other.com/file3/">Other</a>
            <a>No href</a>
          </body>
        </html>
      HTML
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(page_url).and_return(get_response)

      result = described_class.extract_page_links(page_url)
      expect(result).to eq(['https://leechtop.com/file1/', 'http://leechtop.com/file2/'])
    end

    it 'returns an empty array if no links are found' do
      html = "<html><body><a href='https://other.com'>Other</a></body></html>"
      get_response = instance_double(Faraday::Response, status: 200, body: html)
      allow(mock_conn).to receive(:get).with(page_url).and_return(get_response)

      result = described_class.extract_page_links(page_url)
      expect(result).to eq([])
    end

    it 'raises an error if the page fails to load' do
      get_response = instance_double(Faraday::Response, status: 404)
      allow(mock_conn).to receive(:get).with(page_url).and_return(get_response)

      expect { described_class.extract_page_links(page_url) }.to raise_error(/Failed to load page: HTTP 404/)
    end
  end
end
