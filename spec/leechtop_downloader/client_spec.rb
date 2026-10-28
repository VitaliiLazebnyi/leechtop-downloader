# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::Client do
  let(:url) { 'https://leechtop.com/test.bin' }
  let(:direct_link) { 'https://cdn.example/file.rar' }
  let(:download_error) { LeechtopDownloader::Client::DownloadError }

  describe 'LEECHTOP_URL' do
    subject(:pattern) { described_class::LEECHTOP_URL }

    it 'matches http, https and www links to leechtop.com' do
      expect(%w[http://leechtop.com/a https://leechtop.com/a https://www.leechtop.com/a].grep(pattern).size).to eq(3)
    end

    it 'does not match other hosts' do
      expect(%w[https://leechtop.com.example/a https://example.com/leechtop.com/a].grep(pattern)).to be_empty
    end

    it 'only matches at the start of the string, not at the start of a later line' do
      expect(pattern.match?("javascript:void(0)\nhttps://leechtop.com/a")).to be(false)
    end
  end

  describe '.download' do
    before { stub_download(url, 'file data', direct_link: direct_link) }

    it 'LT-REQ-002: downloads the file behind the direct link of the page' do
      expect(described_class.download(url).read).to eq('file data')
    end

    it 'passes the open and read timeouts to Down' do
      allow(Down).to receive(:download).and_call_original
      described_class.download(url)
      expect(Down).to have_received(:download).with(direct_link, open_timeout: 10, read_timeout: 60)
    end

    it 'raises a DownloadError when the file is not found (404)' do
      stub_request(:get, direct_link).to_return(status: 404)
      expect { described_class.download(url) }
        .to raise_error(download_error, 'The file could not be found on the host server (404 Not Found). ' \
                                        'It may have been deleted.')
    end

    it 'raises a DownloadError when the host server rejects the download (4xx)' do
      stub_request(:get, direct_link).to_return(status: [403, 'Forbidden'])
      expect { described_class.download(url) }
        .to raise_error(download_error, 'The host server rejected the download: 403 Forbidden')
    end

    it 'raises a DownloadError when the host server fails (5xx)' do
      stub_request(:get, direct_link).to_return(status: [500, 'Internal Server Error'])
      expect { described_class.download(url) }
        .to raise_error(download_error, 'The host server rejected the download: 500 Internal Server Error')
    end

    it 'raises a DownloadError for extraction failures' do
      stub_page(url, '<html></html>')
      expect { described_class.download(url) }
        .to raise_error(download_error, 'Network or extraction failure: Could not find download button in HTML')
    end
  end

  describe '.download_from_html' do
    before do
      stub_direct_link(direct_link)
      stub_file(direct_link, 'file data')
    end

    it 'downloads the file behind the direct link of the page HTML' do
      expect(described_class.download_from_html(file_page).read).to eq('file data')
    end

    it 'passes the open and read timeouts to Down' do
      allow(Down).to receive(:download).and_call_original
      described_class.download_from_html(file_page)
      expect(Down).to have_received(:download).with(direct_link, open_timeout: 10, read_timeout: 60)
    end

    it 'raises a DownloadError when the AJAX request fails' do
      stub_request(:post, LeechtopPages::AJAX_URL).to_return(status: 500)
      expect { described_class.download_from_html(file_page) }
        .to raise_error(download_error, 'Network or extraction failure: AJAX request failed: HTTP 500')
    end

    it 'raises a DownloadError when the file is not found (404)' do
      stub_request(:get, direct_link).to_return(status: 404)
      expect { described_class.download_from_html(file_page) }.to raise_error(download_error, /\AThe file could not/)
    end
  end

  describe '.fetch_metadata' do
    it 'returns the HTML and the stripped filename of the page' do
      stub_page(url, file_page(filename: 'MyFile.zip'))
      expect(described_class.fetch_metadata(url)).to eq(html: file_page(filename: 'MyFile.zip'), filename: 'MyFile.zip')
    end

    it 'reads the page as UTF-8' do
      stub_request(:get, url).to_return(body: file_page(filename: 'ポケット.zip').b)
      expect(described_class.fetch_metadata(url).fetch(:filename)).to eq('ポケット.zip')
    end

    it 'returns an empty filename if the h4 element is missing' do
      stub_page(url, '<html><body><h4>Other heading</h4></body></html>')
      expect(described_class.fetch_metadata(url).fetch(:filename)).to eq('')
    end

    it 'raises a DownloadError when the page does not load' do
      stub_page(url, 'Not here', status: 404)
      expect { described_class.fetch_metadata(url) }.to raise_error(download_error, 'Failed to load page: HTTP 404')
    end

    it 'raises a DownloadError when the server cannot be reached' do
      stub_request(:get, url).to_timeout
      expect { described_class.fetch_metadata(url) }.to raise_error(download_error, /\AFailed to load page: \S/)
    end

    it 'requests the page with the open and read timeouts' do
      allow(Faraday).to receive(:new).and_call_original
      stub_page(url, file_page)
      described_class.fetch_metadata(url)
      expect(Faraday).to have_received(:new).with(request: { open_timeout: 10, timeout: 60 })
    end
  end

  describe '.extract_direct_url' do
    it 'extracts the tokens of the page and fetches the direct link via AJAX' do
      stub_page(url, file_page)
      stub_direct_link(direct_link)
      expect(described_class.extract_direct_url(url)).to eq(direct_link)
    end

    it 'raises an error if the initial page load fails' do
      stub_page(url, '', status: 500)
      expect { described_class.extract_direct_url(url) }.to raise_error(download_error, 'Failed to load page: HTTP 500')
    end
  end

  describe '.parse_tokens' do
    it 'returns the tokens of the download button and the nonce' do
      expect(described_class.parse_tokens(file_page(data_p: '1', data_mb: '2', nonce: 'n')))
        .to eq(p: '1', mb: '2', nonce: 'n')
    end

    it 'raises an error if the download button is missing' do
      expect { described_class.parse_tokens('<html>"nonce":"n"</html>') }
        .to raise_error(RuntimeError, 'Could not find download button in HTML')
    end

    it 'raises an error if the nonce is missing' do
      expect { described_class.parse_tokens('<a class="go-download-direct" data-p="1" data-mb="2"></a>') }
        .to raise_error(RuntimeError, 'Could not extract nonce from page')
    end

    it 'raises an error if the button has no data-p token' do
      expect { described_class.parse_tokens('<a class="go-download-direct" data-mb="2"></a>"nonce":"n"') }
        .to raise_error(RuntimeError, 'Could not find the tokens of the download button')
    end

    it 'raises an error if the button has no data-mb token' do
      expect { described_class.parse_tokens('<a class="go-download-direct" data-p="1"></a>"nonce":"n"') }
        .to raise_error(RuntimeError, 'Could not find the tokens of the download button')
    end
  end

  describe '.fetch_ajax_direct_link' do
    it 'posts the tokens to the AJAX endpoint and returns the direct link' do
      stub_direct_link(direct_link, data_p: '1', data_mb: '2', nonce: 'n')
      expect(described_class.fetch_ajax_direct_link(p: '1', mb: '2', nonce: 'n')).to eq(direct_link)
    end

    it 'raises a DownloadError when the AJAX request fails' do
      stub_request(:post, LeechtopPages::AJAX_URL).to_return(status: 403)
      expect { described_class.fetch_ajax_direct_link(p: '1', mb: '2', nonce: 'n') }
        .to raise_error(download_error, 'AJAX request failed: HTTP 403')
    end

    it 'raises a DownloadError when the AJAX endpoint cannot be reached' do
      stub_request(:post, LeechtopPages::AJAX_URL).to_raise(Faraday::ConnectionFailed.new('refused'))
      expect { described_class.fetch_ajax_direct_link(p: '1', mb: '2', nonce: 'n') }
        .to raise_error(download_error, 'AJAX request failed: refused')
    end
  end

  describe '.parse_ajax_response' do
    it 'returns the direct link' do
      expect(described_class.parse_ajax_response('{"mes":"https://cdn.example/a"}')).to eq('https://cdn.example/a')
    end

    it 'raises an error if the server rejects the download' do
      expect { described_class.parse_ajax_response('{"mes":"no"}') }
        .to raise_error(RuntimeError, "Server rejected download request: #{JSON.parse('{"mes":"no"}')}")
    end

    it 'raises an error if the response has no link' do
      expect { described_class.parse_ajax_response('{}') }
        .to raise_error(RuntimeError, 'Server rejected download request: {}')
    end

    it 'raises an error if the link is not a string' do
      expect { described_class.parse_ajax_response('{"mes":1}') }
        .to raise_error(RuntimeError, "Server rejected download request: #{JSON.parse('{"mes":1}')}")
    end
  end

  describe '.extract_page_links' do
    let(:page_url) { 'https://example.com/some_page' }

    it 'extracts every leechtop.com link and ignores other links and anchors without href' do
      stub_page(page_url, '<a href="https://leechtop.com/file1/">1</a><a href="http://www.leechtop.com/file2/">2</a>' \
                          '<a href="https://other.com/file3/">3</a><a>No href</a>' \
                          '<a href="javascript:void(0)&#10;https://leechtop.com/file4/">4</a>')
      expect(described_class.extract_page_links(page_url))
        .to eq(['https://leechtop.com/file1/', 'http://www.leechtop.com/file2/'])
    end

    it 'returns an empty array if no links are found' do
      stub_page(page_url, "<html><body><a href='https://other.com'>Other</a></body></html>")
      expect(described_class.extract_page_links(page_url)).to eq([])
    end

    it 'raises a DownloadError if the page fails to load' do
      stub_page(page_url, '', status: 404)
      expect { described_class.extract_page_links(page_url) }
        .to raise_error(download_error, 'Failed to load page: HTTP 404')
    end
  end
end
