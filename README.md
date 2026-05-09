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

```bash
bundle exec bin/leechtop download "https://leechtop.com/example"
```
