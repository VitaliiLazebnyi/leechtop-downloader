# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeechtopDownloader::Filename do
  describe '.sanitize' do
    it 'keeps an ordinary file name' do
      expect(described_class.sanitize('Vol. 1 [Raw].zip')).to eq('Vol. 1 [Raw].zip')
    end

    it 'replaces path separators, so that the file stays inside the destination directory' do
      expect(described_class.sanitize('../../etc/a\\b.zip')).to eq('.._.._etc_a_b.zip')
    end

    it 'replaces NUL bytes' do
      expect(described_class.sanitize("a\0b.zip")).to eq('a_b.zip')
    end
  end

  describe '.repair_encoding' do
    it 'fixes mojibake strings to valid UTF-8' do
      # "ã\u0083\u009Dã\u0082±" is the mojibake for "ポケ"
      expect(described_class.repair_encoding("ã\u0083\u009Dã\u0082±")).to eq('ポケ')
    end

    it 'returns the original string if it is already valid UTF-8' do
      expect(described_class.repair_encoding('ポケット')).to eq('ポケット')
    end

    it 'returns the original string if it is plain ASCII' do
      expect(described_class.repair_encoding('NormalName.rar')).to eq('NormalName.rar')
    end

    it 'returns the original string if the fixed encoding is not valid UTF-8' do
      expect(described_class.repair_encoding('Ã')).to eq('Ã')
    end

    it 'returns a UTF-8 string' do
      expect(described_class.repair_encoding("ã\u0083\u009Dã\u0082±").encoding).to eq(Encoding::UTF_8)
    end
  end

  describe '.for_download' do
    let(:downloaded) { StringIO.new('data').extend(Down::NetHttp::DownloadedFile) }

    it 'prefers the name the server sent, repairing its encoding' do
      allow(downloaded).to receive(:original_filename).and_return("ã\u0083\u009Dã\u0082±.zip")
      expect(described_class.for_download(downloaded, 'page.zip')).to eq('ポケ.zip')
    end

    it 'falls back to the name shown on the page when the server sent none' do
      allow(downloaded).to receive(:original_filename).and_return(nil)
      expect(described_class.for_download(downloaded, 'page.zip')).to eq('page.zip')
    end

    it 'ignores streams that do not come from Down' do
      io = StringIO.new('data')
      io.define_singleton_method(:original_filename) { 'ignored.zip' }
      expect(described_class.for_download(io, 'page.zip')).to eq('page.zip')
    end

    it 'falls back to a name made from the current UTC time when no name is known' do
      allow(Time).to receive(:now).and_return(Time.new(2026, 1, 1, 14, 0, 0, '+02:00'))
      expect(described_class.for_download(StringIO.new('data'), '')).to eq('leechtop_1767268800.bin')
    end
  end
end
