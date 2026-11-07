# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::Client::DownloadError do
  describe '.describe' do
    it 'explains that a missing file (404) may have been deleted' do
      expect(described_class.describe(Down::NotFound.new('404 Not Found')))
        .to eq('The file could not be found on the host server (404 Not Found). It may have been deleted.')
    end

    it 'reports any other client error as rejected by the host server' do
      expect(described_class.describe(Down::ClientError.new('403 Forbidden')))
        .to eq('The host server rejected the download: 403 Forbidden')
    end

    it 'reports a server error as rejected by the host server' do
      expect(described_class.describe(Down::ServerError.new('502 Bad Gateway')))
        .to eq('The host server rejected the download: 502 Bad Gateway')
    end

    it 'reports any other failure as a network or extraction failure' do
      expect(described_class.describe(Down::ConnectionError.new('refused')))
        .to eq('Network or extraction failure: refused')
    end
  end

  it 'is an application error' do
    expect(described_class).to be < LeechtopDownloader::Error
  end
end
