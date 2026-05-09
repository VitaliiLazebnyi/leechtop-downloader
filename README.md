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
