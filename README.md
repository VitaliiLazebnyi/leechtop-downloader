# Leechtop Downloader

A CLI utility for downloading files from leechtop.com.

## Installation

To install the gem globally, run:

```bash
gem install leechtop_downloader
```

This will make the `leechtop` command available in your terminal.

## Local Development Setup

Ruby `>= 3.2.0` is required to run the gem.

1. Clone the repository and run:
   ```bash
   bundle install
   ```
3. Install local git hooks (if desired):
   ```bash
   cp .git/hooks/pre-commit .git/hooks/pre-commit.bak # if existing
   # our automated hook is self-contained.
   ```

## Testing

This project mandates 100% test coverage.

```bash
bundle exec rspec
```

## Static Analysis

This project mandates zero linting or type-checking errors.

```bash
bundle exec rubocop
bundle exec srb tc
```

## Usage

The CLI can download files from direct `leechtop.com` links or automatically extract and download multiple links from any generic HTML webpage. All downloads are saved in the current folder by default, which can be overridden via the `--destination` option.

### Direct Download
Provide a direct Leechtop URL:
```bash
leechtop download "https://leechtop.com/example1"
```

### Batch Download via HTML Parsing
Provide the URL of an HTML page (like a manga chapter index) containing `leechtop.com` links. The tool will parse the page, extract all valid links, and download them sequentially:
```bash
leechtop download "https://dl-raw.ac/example-manga-page/"
```

### Multiple URLs
You can pass any combination of direct URLs or generic HTML pages at once:
```bash
leechtop download "https://leechtop.com/example1" "https://dl-raw.ac/example-page/"
```

### Batch Download via Text File
You can also pass the path to a local text file that contains a list of URLs (one per line). The tool will read the file and download each link:
```bash
# links.txt contains URLs separated by newlines
leechtop download links.txt
```

### Parallel & Concurrent Downloading
Since `leechtop.com` does not allow parallel downloads, the tool enforces a strict global application lock. If you attempt to run multiple instances of the downloader concurrently in different terminal tabs, any secondary instances will automatically detect the active process, print an error message, and safely exit to prevent conflicts.

### Options

**`--skip-existing`** (Default: `true`)
By default, the tool will skip downloading files that already exist in the destination directory. If you want to force re-downloading and overwrite existing files, pass `--no-skip-existing`:
```bash
leechtop download "https://leechtop.com/example1" --no-skip-existing
```

**`--destination`** (Default: `.`)
Specify a custom destination directory for downloaded files:
```bash
leechtop download "https://leechtop.com/example1" --destination="/path/to/custom/dir"
```
