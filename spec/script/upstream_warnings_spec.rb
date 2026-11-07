# typed: false
# frozen_string_literal: true

# Copyright (c) 2026 Vitalii Lazebnyi

require 'spec_helper'
require_relative '../../script/upstream_warnings'

RSpec.describe(UpstreamWarnings) do
  # Stands in for Ruby's Warning module: records what would be printed.
  let(:printer_class) do
    Class.new do
      define_method(:printed) { @printed ||= [] }
      define_method(:warn) { |message, **| printed << message }
    end
  end
  let(:printer) { printer_class.new.extend(described_class) }
  let(:gems)    { '/usr/lib/ruby/gems/4.0.0/gems'           }

  it 'drops a listed warning of the listed gem version' do
    printer.warn("#{gems}/yard-0.9.45/lib/yard/cli/yardoc.rb:230: warning: setting Encoding.default_internal\n")
    expect(printer.printed).to(eq([]))
  end

  it 'identifies a warning of several lines by its first line' do
    helpers = "#{gems}/tapioca-0.20.0/lib/tapioca/runtime/helpers.rb"
    message = "#{helpers}:34: warning: method redefined; discarding old exit\n" \
      "#{helpers}:6: warning: previous definition of exit was here\n"
    printer.warn(message)
    expect(printer.printed).to(eq([]))
  end

  it 'prints the same warning of another gem version' do
    message = "#{gems}/yard-0.9.46/lib/yard/cli/yardoc.rb:230: warning: setting Encoding.default_internal\n"
    printer.warn(message)
    expect(printer.printed).to(eq([message]))
  end

  it 'prints another warning of a listed file' do
    message = "#{gems}/yard-0.9.45/lib/yard/cli/yardoc.rb:9: warning: assigned but unused variable - x\n"
    printer.warn(message)
    expect(printer.printed).to(eq([message]))
  end

  it 'prints a warning whose listed text is not at the end of its first line' do
    message = "#{gems}/yard-0.9.45/lib/yard/cli/yardoc.rb:9: warning: setting Encoding.default_internal twice\n"
    printer.warn(message)
    expect(printer.printed).to(eq([message]))
  end

  it 'prints any warning of this repository' do
    message = "lib/leechtop_downloader/cli.rb:3: warning: method redefined; discarding old exit\n"
    printer.warn(message, category: nil)
    expect(printer.printed).to(eq([message]))
  end
end
