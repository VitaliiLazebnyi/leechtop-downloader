# Changelog

## Unreleased

### Fixed

- File names from the page title or the `Content-Disposition` header can no longer write outside the destination
  directory; path separators and NUL bytes are replaced with `_` (BUG-LT-002).
- A page that fails to load, or a server that cannot be reached, no longer aborts the whole run: the error is printed
  and the next URL is processed (BUG-LT-003).
- Only strings that start with a leechtop.com URL are treated as leechtop.com links (BUG-LT-004).
- Streams are copied in metric 8 kB chunks (BUG-LT-005).
- The executable no longer triggers Ruby warnings; the text file of links is read as UTF-8 (BUG-LT-006).
- The release workflow publishes the version committed in `lib/leechtop_downloader/version.rb` and refuses a tag
  that does not match it, instead of rewriting the version from the tag at release time.

### Changed

- Ruby 3.3 or newer is required (Ruby 3.2 reached its end of life); development uses Ruby 4.0.9.
- Runtime dependencies require their current releases: dotenv 3.2, down 5.6, faraday 2.15, nokogiri 1.19 and
  thor 1.5.
- `Gemfile.lock` is committed, so CI checks the exact bundle the Sorbet RBIs were generated from.
- The internals of the CLI moved into `LeechtopDownloader::Downloader`, `AppLock`, `DownloadLock` and `Filename`;
  `LeechtopDownloader::CLIHelpers` was removed.
