# CLAUDE.md

This file provides guidance to Claude Code when working with the Nodal codebase.

## Project Overview

Nodal is a **B2B e-commerce platform** with multi-tenancy support. Each Organisation has its own customers, products, orders, and pricing rules.

**Tech Stack:** Rails 7.1, PostgreSQL, Hotwire (Turbo + Stimulus), Bootstrap 5

**Key Business Domains:**
- **Organisations** - Multi-tenant containers with currency/tax settings
- **Products & Categories** - Catalog management
- **Orders** - Shopping cart, checkout, order history
- **Discounts** - Complex pricing with 4 discount types and stacking rules
- **Analytics** - Dashboard with KPIs and metrics

## Common Commands

```bash
# Development server
bin/rails server

# Database
bin/rails db:create db:migrate db:seed

# Tests
bin/rails test                           # All tests
bin/rails test test/models/order_test.rb # Specific file

# Console
bin/rails console

# Assets (importmap-based, no webpack)
bin/importmap pin <package>
```

## Architecture

### Directory Structure

```
app/
├── controllers/
│   ├── bo/                 # Back office (admin) controllers
│   └── storefront/         # Customer-facing controllers
├── models/
│   └── concerns/           # Shared model behavior (Slugable)
├── services/               # Business logic
│   ├── discount_calculator.rb
│   └── dashboard/metrics.rb
├── policies/               # Pundit authorization
├── javascript/controllers/ # Stimulus controllers
├── views/
│   ├── bo/                 # Admin views
│   ├── storefront/         # Customer views
│   └── shared/             # Partials (_navbar, _sidebar, _flashes)
└── mailers/
```

### Core Models

| Model | Purpose |
|-------|---------|
| **Organisation** | Multi-tenant root. Has currency (EUR/CHF/USD/GBP), tax_rate, shipping_cost |
| **Member** | Team members (Devise auth). Linked to orgs via OrgMember with roles |
| **Customer** | B2B customers (Devise auth). Scoped to organisation |
| **Product** | Catalog items with unit_price, sku, photo (ActiveStorage) |
| **Category** | Product categories per organisation |
| **Order** | Shopping cart (draft) and placed orders. Complex discount tracking |
| **OrderItem** | Line items with quantity, unit_price, discount_percentage |
| **Address** | Polymorphic billing/shipping addresses |

### Discount Models (4 types)

| Model | Purpose |
|-------|---------|
| **ProductDiscount** | Volume discounts (min_quantity threshold) |
| **CustomerDiscount** | Global tier discount for a customer |
| **CustomerProductDiscount** | Custom pricing for customer-product pair |
| **OrderDiscount** | Order total threshold triggers discount |

All discounts have: `discount_type` (percentage/fixed), `discount_value`, `valid_from/until`, `stackable`, `active`

### Key Services

**DiscountCalculator** (`app/services/discount_calculator.rb`)
- Calculates effective discount from multiple sources
- Stacking rules: best non-stackable + all stackable (multiplicative)
- Methods: `effective_discount`, `final_price`, `discount_breakdown`

**Dashboard::Metrics** (`app/services/dashboard/metrics.rb`)
- Calculates KPIs: total_sales, order_count, AOV, retention_rate
- Product/customer analytics, discount impact analysis

## Key Patterns

### Multi-Tenancy
- All routes scoped under `/:org_slug/`
- `current_organisation` set via URL parameter
- Data scoped to organisation in controllers/policies

### Authentication (Devise)
- **Members**: Team/admin users, can belong to multiple orgs
- **Customers**: B2B buyers, scoped to single org, use `devise_invitable`
- Controllers: `Members::SessionsController`, `Customers::SessionsController`

### Authorization (Pundit)
- Policies in `app/policies/` for each model
- `PunditContext` wraps `user` + `organisation`
- Use `authorize @resource` and `policy_scope(Model)`

### Money Handling (money-rails)
- Fields stored as `_cents` integers (e.g., `unit_price_cents`)
- Access via `monetize` (e.g., `order.total_amount`)
- Organisation has `currency` setting

### Controller Namespaces
- `Bo::` - Back office (requires Member auth, `check_membership`)
- `Storefront::` - Customer-facing (requires Customer auth)

## Coding Conventions

### Naming
- Models: Singular CamelCase (`OrderItem`, `ProductDiscount`)
- Controllers: Plural, namespaced (`Bo::ProductsController`)
- Database: snake_case with `_cents` suffix for money

### Patterns Used
- **Service Objects**: Complex logic in `app/services/`
- **Concerns**: Shared behavior in `app/models/concerns/` (e.g., `Slugable`)
- **Scopes**: Named scopes for common queries (`active`, `placed`, `draft`)
- **Callbacks**: Auto-generate order numbers, recalculate discounts

### Forms
- SimpleForm with Bootstrap integration
- Nested attributes for OrderItems in Orders

### Frontend
- Stimulus controllers for interactivity
- Turbo for SPA-like navigation
- No webpack/esbuild - uses importmap

## Environment Variables

Required in `.env`:
```
# LLM APIs (ruby_llm gem)
GITHUB_TOKEN=         # OpenAI via Azure
ANTHROPIC_API_KEY=    # Claude API
GEMINI_API_KEY=       # Google Gemini

# File storage (production)
CLOUDINARY_URL=

# Email (production)
SENDGRID_API_KEY=
```

## Testing

```bash
bin/rails test                    # Run all tests
bin/rails test test/models/       # Model tests only
bin/rails test test/system/       # System tests (Capybara + Selenium)
```

Test structure:
- `test/models/` - Unit tests
- `test/system/` - Integration tests
- `test/mailers/previews/` - Email previews

## Key Files Reference

| File | Purpose |
|------|---------|
| `config/routes.rb` | Multi-tenant routing structure |
| `app/controllers/application_controller.rb` | Base auth/org setup |
| `app/services/discount_calculator.rb` | Pricing logic |
| `app/services/dashboard/metrics.rb` | Analytics calculations |
| `config/initializers/money.rb` | Currency configuration |
| `config/initializers/ruby_llm.rb` | LLM provider setup |

## Claude Agents

Custom agents are defined in `.claude/agents/` for specialized tasks:

| Agent | Purpose |
|-------|---------|
| `frontend-refactor` | Frontend specialist for refactoring ERB templates, SCSS, and Stimulus controllers. Follows BEM naming, semantic HTML5, and Rails view best practices. |

Usage: Reference agents via Claude Code's agent functionality.
