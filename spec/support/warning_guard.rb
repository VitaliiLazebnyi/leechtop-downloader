# typed: false
# frozen_string_literal: true

# Copyright (c) 2026 Vitalii Lazebnyi

# Turns every Ruby warning (from this project or from a gem) into a test failure: the specs run with
# warnings enabled (`--warnings`), and a warning is a defect to fix, never noise to ignore.
module WarningGuard
  # Fails the suite: a warning was emitted, or an example was skipped.
  class Failure < StandardError; end

  COLLECTED = Queue.new
  public_constant :COLLECTED

  # Returns and forgets the warnings collected so far.
  # @return [Array<String>]
  def self.drain
    Array.new(COLLECTED.size) { COLLECTED.pop }
  end

  # Records the warning, then defers to Ruby's default handling (which prints it).
  # @param message [String]
  # @return [void]
  def warn(message, ...)
    COLLECTED << message
    super
  end
end

Warning[:deprecated] = true
Warning[:experimental] = true
Warning[:performance] = true
Warning.singleton_class.prepend(WarningGuard)
