# Contributing to Password Pusher

Password Pusher is an open source web application for sharing sensitive information
(passwords, text, files, URLs) through self-expiring, encrypted links. It is built
with Ruby on Rails and licensed under the Apache License 2.0.

Contributions of all kinds are welcome: bug fixes, new features, documentation
improvements, translations, and testing.

---

## Code of Conduct

This project has a [Code of Conduct](CODE_OF_CONDUCT.md). By participating you
agree to abide by its terms.

---

## Getting Started

Full development environment setup instructions are in
[docs/development.md](docs/development.md). The short version:

```bash
bin/setup && bin/dev
```

This starts the Rails server on port 5100, the Solid Queue worker, and the CSS/JS
watchers (see `Procfile.dev`).

For an overview of how the codebase is organized, see
[docs/architecture.md](docs/architecture.md).

---

## Reporting Issues

- **Bugs and feature requests** -- Open a GitHub Issue with a clear description,
  steps to reproduce (for bugs), and expected vs. actual behavior.
- **Security vulnerabilities** -- Do NOT open a public issue. Follow the process in
  [SECURITY.md](SECURITY.md) and use GitHub's
  [Report a vulnerability](https://github.com/pglombardo/PasswordPusher/security/advisories/new)
  feature.

---

## Pull Request Process

1. Fork the repository and create a branch from `master`.
2. Keep PRs focused -- one logical change per PR.
3. Write descriptive commit messages explaining *why*, not just *what*.
4. Ensure CI passes (tests, linting, security scan).
5. Update or add tests for any changed behavior.
6. If your change affects configuration or user-facing behavior, update the
   relevant documentation.
7. Be responsive to review feedback.

---

## Coding Conventions

### Ruby / Rails

- **RuboCop** and **ErbLint** are enforced via pre-commit hooks (Overcommit). Run
  them before committing:
  ```bash
  bundle exec rubocop
  bundle exec erblint --lint-all
  ```
- Use `optional: true` on all new `belongs_to` associations.
- Gate new features behind a feature flag using the `Settings.enable_xxx` pattern
  with a corresponding `PWP__ENABLE_XXX` environment variable override. New
  features should be **disabled by default**.
- Inherit controllers from `BaseController`, not `ApplicationController` directly.
  `BaseController` includes shared rescue handlers and the team 2FA enforcement
  concern.
- Use [Lockbox](https://github.com/ankane/lockbox) (`has_encrypted`) for any new
  fields that store sensitive data.
- Settings are managed through the [Config gem](https://github.com/rubyconfig/config)
  in `config/settings.yml`. Environment variable overrides follow the `PWP__`
  prefix convention with double underscores for nesting.

### JavaScript / Frontend

- Use **Hotwire** (Turbo + Stimulus) for interactivity. Do not introduce React,
  Vue, or other SPA frameworks.
- Stimulus controllers live in `app/javascript/controllers/`.
- Stylesheets use Bootstrap 5 via cssbundling-rails.

### Database

- SQLite for development, with PostgreSQL and MySQL supported in production.
- Use standard Rails migrations. Avoid raw SQL when possible.

---

## Testing

Password Pusher uses **Minitest** with fixtures.

```bash
# Run the full test suite
bin/rails test

# Run system tests (requires a browser driver)
bin/rails test:system

# Run a specific test file
bin/rails test test/models/push_test.rb
```

- All new code needs tests.
- Fixtures live in `test/fixtures/*.yml`.
- The test helper (`test/test_helper.rb`) strips all `PWP__` environment variables
  before tests run, so tests always start from a clean settings state.
- Use `assert_audit_log_created` and other helpers defined in `test_helper.rb`.

---

## Security Scanning

Run [Brakeman](https://brakemanscanner.org/) before submitting PRs that touch
controllers, views, or routes:

```bash
bundle exec brakeman
```

---

## Architecture Quick Reference

See [docs/architecture.md](docs/architecture.md) for the full picture. Key
concepts:

- **Push kinds**: text, file, URL, QR code (enum on `Push` model).
- **Settings resolution**: Team Forced > Team Default > User Policy > Global Settings.
- **Feature flags**: `Settings.enable_xxx` / `PWP__ENABLE_XXX` environment variables.
- **Encrypted fields**: Lockbox (`has_encrypted :payload, :note, :passphrase`).

---

## License

By contributing to Password Pusher you agree that your contributions will be
licensed under the [Apache License 2.0](LICENSE).
