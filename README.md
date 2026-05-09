# Leechtop Downloader

A CLI utility for downloading files from leechtop.com, adhering to strict quality and testing standards.

## Setup

1. Ensure you have Ruby 4.0.3 installed.
2. Clone the repository and run:
   ```bash
   bundle install
   ```
3. Copy the environment template:
   ```bash
   cp .env.example .env
   ```
4. Install local git hooks (if desired):
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

The CLI can download files from direct `leechtop.com` links or automatically extract and download multiple links from any generic HTML webpage. All downloads are saved in the `downloads/` directory.

### Direct Download
Provide a direct Leechtop URL:
```bash
bundle exec bin/leechtop download "https://leechtop.com/example1"
```

### Batch Download via HTML Parsing
Provide the URL of an HTML page (like a manga chapter index) containing `leechtop.com` links. The tool will parse the page, extract all valid links, and download them sequentially:
```bash
bundle exec bin/leechtop download "https://dl-raw.ac/example-manga-page/"
```

### Multiple URLs
You can pass any combination of direct URLs or generic HTML pages at once:
```bash
bundle exec bin/leechtop download "https://leechtop.com/example1" "https://dl-raw.ac/example-page/"
```

### Parallel & Concurrent Downloading
The tool features robust file-based locking. You can safely open multiple terminal tabs and run the downloader in parallel on different (or even the same) URLs. The tool will automatically detect active downloads across processes and gracefully skip any file currently being handled by another instance, preventing duplicates and data corruption.

### Options

**`--skip-existing`** (Default: `true`)
By default, the tool will skip downloading files that already exist in the `downloads/` directory. If you want to force re-downloading and overwrite existing files, pass `--no-skip-existing`:
```bash
bundle exec bin/leechtop download "https://leechtop.com/example1" --no-skip-existing
```
