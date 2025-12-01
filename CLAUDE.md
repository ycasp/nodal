# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nodal is a Rails 7.1 application generated with Le Wagon's rails-templates. It uses PostgreSQL, Hotwire (Turbo + Stimulus), and integrates with multiple LLM providers via the ruby_llm gem.

## Common Commands

```bash
# Start the development server
bin/rails server

# Database operations
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# Run tests
bin/rails test

# Run a specific test file
bin/rails test test/path/to/test_file.rb

# Rails console
bin/rails console

# Asset management (importmap-based)
bin/importmap pin <package>
```

## Architecture

### Frontend Stack
- **Hotwire**: Turbo Rails for SPA-like navigation, Stimulus for JavaScript controllers
- **CSS**: Bootstrap 5 with sassc-rails, Font Awesome icons
- **JavaScript**: importmap-rails (no webpack/esbuild), Stimulus controllers in `app/javascript/controllers/`

### Key Integrations
- **LLM**: ruby_llm gem configured in `config/initializers/ruby_llm.rb` - supports OpenAI (via Azure), Anthropic, and Gemini APIs
- **File Storage**: Active Storage with Cloudinary for production (configured in `config/storage.yml`)
- **Authentication**: Devise gem (set up but no user model yet)
- **Markdown**: kramdown with GFM parser and rouge syntax highlighting

### Environment Variables
Required in `.env` for development:
- `GITHUB_TOKEN` - OpenAI-compatible API via Azure inference
- `ANTHROPIC_API_KEY` - Anthropic Claude API
- `GEMINI_API_KEY` - Google Gemini API
- Cloudinary credentials for production file uploads

### Generator Configuration
Rails generators are configured to skip assets, helpers, and fixtures (`config/application.rb`).
