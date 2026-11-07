# typed: false
# frozen_string_literal: true

# Copyright (c) 2026 Vitalii Lazebnyi

require 'spec_helper'

RSpec.describe(LeechtopDownloader::Client::ExtractionError) do
  it 'is an application error' do
    expect(described_class.new).to(be_a(LeechtopDownloader::Error))
  end
end
