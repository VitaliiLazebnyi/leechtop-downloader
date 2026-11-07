# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::Downloader do
  subject(:downloader) { described_class.new(skip_existing: skip_existing, destination: 'downloads') }

  let(:skip_existing) { true }
  let(:url) { 'https://leechtop.com/example' }
  let(:direct_link) { 'https://cdn.example/files/MyFile.zip' }

  describe '#process' do
    context 'with a leechtop.com file page' do
      before { stub_download(url, 'file data', filename: 'MyFile.zip', direct_link: direct_link) }

      it 'LT-REQ-002, LT-REQ-003: downloads the file into the destination, reporting each step', :aggregate_failures do
        expect { downloader.process(url) }.to output("Downloading: #{url}\nBypassing countdown and extracting " \
                                                     "direct link...\nStarting download of file: MyFile.zip...\n" \
                                                     "Successfully downloaded MyFile.zip (9 bytes)\n").to_stdout
        expect(File.read('downloads/MyFile.zip')).to eq('file data')
      end

      it 'removes its lock file afterwards', :aggregate_failures do
        expect { downloader.process(url) }.to output.to_stdout
        expect(Dir.children('downloads')).to eq(['MyFile.zip'])
      end

      it 'downloads nothing while another process holds the lock of the file', :aggregate_failures do
        FileUtils.mkdir_p('downloads')
        File.write('downloads/MyFile.zip.lock', '')
        expect { downloader.process(url) }.to output(/MyFile.zip is currently being downloaded/).to_stdout
        expect(a_request(:get, direct_link)).not_to have_been_made
      end
    end

    context 'when the file already exists (LT-REQ-006)' do
      before do
        stub_download(url, 'new data', filename: 'MyFile.zip', direct_link: direct_link)
        FileUtils.mkdir_p('downloads')
        File.write('downloads/MyFile.zip', 'old data')
      end

      it 'skips the download when skip_existing is true', :aggregate_failures do
        expect { downloader.process(url) }.to output(/^File MyFile.zip already exists. Skipping.\n\z/).to_stdout
        expect(a_request(:get, direct_link)).not_to have_been_made
      end
    end

    context 'when the file already exists and skip_existing is false' do
      let(:skip_existing) { false }

      before do
        stub_download(url, 'new data', filename: 'MyFile.zip', direct_link: direct_link)
        FileUtils.mkdir_p('downloads')
        File.write('downloads/MyFile.zip', 'old data')
      end

      it 'downloads the file under a new name, keeping the existing file', :aggregate_failures do
        expect { downloader.process(url) }.to output(/Successfully downloaded MyFile_1.zip/).to_stdout
        expect(File.read('downloads/MyFile.zip')).to eq('old data')
      end
    end

    context 'when the page shows no file name' do
      before do
        stub_download(url, 'file data', filename: '', direct_link: direct_link)
        FileUtils.mkdir_p('downloads')
      end

      it 'downloads the file even though the destination directory exists', :aggregate_failures do
        expect { downloader.process(url) }.to output(/Starting download of file: unknown.../).to_stdout
        expect(Dir.children('downloads')).to eq(['MyFile.zip'])
      end

      it 'names the file after the current UTC time when the server does not name it either' do
        stub_download(url, 'file data', filename: '', direct_link: 'https://cdn.example/')
        allow(Time).to receive(:now).and_return(Time.at(1_767_268_800))
        expect { downloader.process(url) }.to output(/Successfully downloaded leechtop_1767268800.bin/).to_stdout
      end
    end

    context 'when the server names the file' do
      before do
        stub_download(url, 'file data', filename: 'Page name.zip', direct_link: direct_link,
                                        headers: { content_disposition: 'attachment; filename="Server name.zip"' })
      end

      it 'saves the file under the name the server sent' do
        expect { downloader.process(url) }.to output(/Successfully downloaded Server name.zip/).to_stdout
      end
    end

    context 'when a file name contains path separators (regression)' do
      it 'saves a page title with a slash as a single file inside the destination', :aggregate_failures do
        stub_download(url, 'data', filename: 'Vol 1/2.zip', direct_link: 'https://cdn.example/')
        expect { downloader.process(url) }.to output(/Successfully downloaded Vol 1_2.zip/).to_stdout
        expect(Dir.children('downloads')).to eq(['Vol 1_2.zip'])
      end

      it 'never lets the server write outside the destination', :aggregate_failures do
        stub_download(url, 'data', filename: '', headers: { content_disposition: 'attachment; filename="../evil"' })
        expect { downloader.process(url) }.to output(/Successfully downloaded .._evil/).to_stdout
        expect(Dir.children('.')).to eq(['downloads'])
      end
    end

    context 'when the download fails' do
      before { stub_page(url, 'gone', status: 404) }

      it 'reports the error instead of raising it' do
        expect { downloader.process(url) }.to output(/^Error downloading #{url}: Failed to load page: HTTP 404\n\z/)
          .to_stdout
      end
    end

    context 'with any other page' do
      let(:page_url) { 'https://example.com/some_manga' }
      let(:links) { ['https://leechtop.com/file1', 'https://leechtop.com/file2'] }

      before do
        stub_page(page_url, links.map { |link| %(<a href="#{link}">x</a>) }.join)
        stub_download(links.first, 'one', filename: 'one.zip', data_p: '1')
        stub_download(links.last, 'two', filename: 'two.zip', data_p: '2')
      end

      it 'downloads every leechtop.com link on the page in order', :aggregate_failures do
        expect { downloader.process(page_url) }.to output(
          /\AFetching links from: #{page_url}\nFound 2 leechtop.com link\(s\). Downloading...\n.*one.zip.*two.zip/m
        ).to_stdout
        expect(Dir.children('downloads').sort).to eq(%w[one.zip two.zip])
      end

      it 'continues with the next link when one download fails' do
        stub_page(links.first, '', status: 500)
        expect { downloader.process(page_url) }.to output(/HTTP 500\n.*Successfully downloaded two.zip/m).to_stdout
      end

      it 'reports a page without leechtop.com links' do
        stub_page(page_url, '<a href="https://example.com/a">a</a>')
        expect { downloader.process(page_url) }
          .to output("Fetching links from: #{page_url}\nNo leechtop.com links found on #{page_url}\n").to_stdout
      end

      it 'reports a page that fails to load instead of raising (regression)' do
        stub_page(page_url, '', status: 503)
        expect { downloader.process(page_url) }
          .to output("Fetching links from: #{page_url}\nError fetching links from #{page_url}: " \
                     "Failed to load page: HTTP 503\n").to_stdout
      end
    end
  end

  describe '#process_argument' do
    before { %w[a b].each { |name| stub_page("https://leechtop.com/#{name}", '', status: 404) } }

    it 'processes a URL' do
      expect { downloader.process_argument('https://leechtop.com/a') }
        .to output(%r{\ADownloading: https://leechtop.com/a\n.*HTTP 404\n\z}m).to_stdout
    end

    it 'processes every non-empty line of a text file, in order' do
      File.write('links.txt', "https://leechtop.com/a\n\n  \n  https://leechtop.com/b  \n")
      expect { downloader.process_argument('links.txt') }
        .to output(%r{\ADownloading: https://leechtop.com/a\n.*\nDownloading: https://leechtop.com/b\n.*404\n\z}m)
        .to_stdout
    end
  end

  describe '.urls_in' do
    it 'returns the argument itself when it is not a file' do
      expect(described_class.urls_in('https://leechtop.com/a')).to eq(['https://leechtop.com/a'])
    end

    it 'returns the stripped, non-empty lines of a file' do
      File.write('links.txt', " a \r\n\nb")
      expect(described_class.urls_in('links.txt')).to eq(%w[a b])
    end

    it 'reads the file as UTF-8, whatever the locale' do
      File.write('links.txt', 'https://leechtop.com/ポケ')
      allow(File).to receive(:readlines).and_call_original
      described_class.urls_in('links.txt')
      expect(File).to have_received(:readlines).with('links.txt', chomp: true, encoding: Encoding::UTF_8)
    end
  end

  describe '.page' do
    it 'returns the HTML of the page and the sanitized name of its file' do
      stub_page(url, file_page(filename: 'a/b.zip'))
      expect(described_class.page(url)).to eq([file_page(filename: 'a/b.zip'), 'a_b.zip'])
    end
  end
end
