# Leechtop Downloader

A CLI utility for downloading files from leechtop.com.

## Installation

To install the gem globally, run:

```bash
gem install leechtop_downloader
```

This will make the `leechtop` command available in your terminal.

## Development

Ruby `>= 3.3` is required; development uses the Ruby in `.ruby-version`.

```bash
bundle install
git config core.hooksPath .githooks   # optional: run the fast gates before every commit
bundle exec rake                      # every gate CI enforces (see below)
```

The project tolerates no warnings and no suppressions. `bundle exec rake` runs:

- RSpec with Ruby warnings enabled (any warning fails the run), 100% line and branch coverage, no pending or skipped
  examples, and no real network access (WebMock);
- the original spec suite of `main`, against the current code, to prove that behavior did not change;
- RuboCop with its plugins, with no todo file and no inline directives;
- a check that no file contains an inline suppression of any tool;
- Sorbet at `typed: strict` (after verifying that the Tapioca-generated gem RBIs match the bundle);
- YARD (100% documented), Reek and Flay (no smell, no duplication) and bundler-audit.

Mutation testing (`bundle exec rake mutant`, every mutation must be killed) and the outdated-dependency check
(`bundle exec rake outdated`) run in CI as well. See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete list of
gates, including the workflow, shell, Markdown, spelling and secret scanners.

## Usage

The CLI can download files from direct `leechtop.com` links or automatically extract and download multiple links
from any generic HTML webpage. All downloads are saved in the current folder by default, which can be overridden via
the `--destination` option.

### Direct Download

Provide a direct Leechtop URL:

```bash
leechtop download "https://leechtop.com/example1"
```

### Batch Download via HTML Parsing

Provide the URL of an HTML page (like a manga chapter index) containing `leechtop.com` links. The tool will parse the
page, extract all valid links, and download them sequentially:

```bash
leechtop download "https://dl-raw.ac/example-manga-page/"
```

### Multiple URLs

You can pass any combination of direct URLs or generic HTML pages at once:

```bash
leechtop download "https://leechtop.com/example1" "https://dl-raw.ac/example-page/"
```

A URL that fails (a page that does not load, a file that was deleted) is reported, and the remaining URLs are still
downloaded.

### Batch Download via Text File

You can also pass the path to a local text file (UTF-8) that contains a list of URLs, one per line. The tool will read
the file and download each link:

```bash
# links.txt contains URLs separated by newlines
leechtop download links.txt
```

### Parallel & Concurrent Downloading

Since `leechtop.com` does not allow parallel downloads, the tool enforces a strict global application lock. If you
attempt to run multiple instances of the downloader concurrently in different terminal tabs, any secondary instances
will automatically detect the active process, print an error message, and safely exit to prevent conflicts.

### Options

**`--skip-existing`** (Default: `true`)
By default, the tool skips downloading files that already exist in the destination directory. To download them
again, pass `--no-skip-existing`; existing files are never overwritten, the new download is saved with a numeric
suffix (`file_1.zip`, `file_2.zip`, ...):

```bash
leechtop download "https://leechtop.com/example1" --no-skip-existing
```

**`--destination`** (Default: `.`)
Specify a custom destination directory for downloaded files:

```bash
leechtop download "https://leechtop.com/example1" --destination="/path/to/custom/dir"
```

File names sent by the server are always saved inside the destination directory: path separators in a name are
replaced with `_`.
