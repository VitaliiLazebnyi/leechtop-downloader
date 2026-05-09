# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module LeechtopDownloader
  # CLIHelpers provides shared utility methods for CLI operations
  module CLIHelpers
    extend T::Sig

    sig { params(filename_hint: String, skip_existing: T::Boolean).returns(T::Boolean) }
    def skip_download?(filename_hint, skip_existing)
      return false unless skip_existing && !filename_hint.empty?

      if File.exist?(File.join("downloads", filename_hint))
        Kernel.puts "File #{filename_hint} already exists. Skipping."
        true
      else
        false
      end
    end

    sig { params(url: String, filename_hint: String).returns(String) }
    def lock_path_for(url, filename_hint)
      lock_filename = filename_hint.empty? ? "#{Digest::MD5.hexdigest(url)}.lock" : "#{filename_hint}.lock"
      File.join("downloads", lock_filename)
    end

    sig { params(lock_path: String).returns(T::Boolean) }
    def acquire_lock(lock_path)
      File.new(lock_path, File::WRONLY | File::CREAT | File::EXCL).close
      true
    rescue Errno::EEXIST
      false
    end

    sig { params(filename_hint: String).void }
    def skip_locked(filename_hint)
      name = filename_hint.empty? ? "File" : "File #{filename_hint}"
      Kernel.puts "#{name} is currently being downloaded by another process. Skipping."
    end
  end
end
