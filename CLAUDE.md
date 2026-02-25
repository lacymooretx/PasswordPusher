# CLAUDE.md -- AI Assistant Context for PasswordPusher

Password Pusher is an open source Rails application for sharing sensitive
information (passwords, text, files, URLs) via self-expiring, encrypted links.
It supports multiple push types, user accounts with 2FA, SSO, teams, branding,
and a JSON API. The codebase runs on Rails 8.1.1 with Ruby 4.0.1.

---

## Quick Commands

| Task | Command |
|------|---------|
| Dev server (port 5100) | `bin/dev` |
| Run all tests | `bin/rails test` |
| System tests | `bin/rails test:system` |
| Ruby lint | `bundle exec rubocop` |
| ERB lint | `bundle exec erblint --lint-all` |
| Security scan | `bundle exec brakeman` |
| Console | `bin/rails console` |
| i18n check | `bundle exec i18n-tasks health` |

---

## Key Directories

```
app/models/              Core domain models (Push, User, Team, etc.)
app/models/concerns/     SetPushAttributes, LogEvents, TokenAuthentication
app/controllers/         BaseController is the parent for feature controllers
app/controllers/api/     JSON API controllers
app/controllers/concerns/ SetLocale, SetPushAttributes, LogEvents, TeamTwoFactorEnforcement
app/controllers/users/   Devise overrides, 2FA, SSO callbacks
app/javascript/controllers/ Stimulus controllers (copy, countdown, form, pwgen, etc.)
app/views/               ERB templates organized by resource
config/settings.yml      All feature flags and application defaults (Config gem)
config/routes/           Split route files (pushes, users, teams, two_factor, etc.)
db/migrate/              Migrations (SQLite dev, supports PostgreSQL/MySQL)
test/                    Minitest + fixtures
test/fixtures/           YAML fixtures for all models
```

---

## Architecture Essentials

### Push Kinds

The `Push` model uses an enum with four kinds: `text`, `file`, `url`, `qr`.
Each kind maps to a settings namespace (`pw`, `files`, `url`, `qr`) in
`config/settings.yml` for expiration defaults, view limits, and feature toggles.

### Settings Resolution Chain

When creating a push, settings resolve in priority order:

1. **Team Forced** -- team policy forces a value (cannot be overridden)
2. **Team Default** -- team policy suggests a default
3. **User Policy** -- logged-in user's personal defaults (`UserPolicy` model)
4. **Global Settings** -- `config/settings.yml` / `PWP__` env vars

### Feature Flags

All features are gated via `Settings.enable_xxx` with env var overrides
`PWP__ENABLE_XXX`. Features are disabled by default.

### Encrypted Fields

Lockbox gem provides `has_encrypted`. The `Push` model encrypts `:payload`,
`:note`, and `:passphrase`. The `User` model encrypts `:otp_secret`.
Ciphertext is stored in `*_ciphertext` columns.

### Controller Inheritance

All feature controllers inherit from `BaseController`, which extends
`ApplicationController` and includes `TeamTwoFactorEnforcement`.

### Key Gems

- **Rails 8.1.1** -- framework
- **Devise 5.0** -- authentication
- **Config** -- settings from YAML + env vars
- **Lockbox** -- field-level encryption
- **ROTP** -- TOTP for 2FA
- **OmniAuth** -- Google and Microsoft SSO
- **Kaminari** -- pagination
- **Apipie** -- API documentation
- **Turbo + Stimulus** -- Hotwire frontend

---

## Testing Conventions

- Framework: **Minitest** with fixtures (`test/fixtures/*.yml`)
- `test_helper.rb` strips all `PWP__` env vars before tests run
- Devise helpers included via `Devise::Test::IntegrationHelpers`
- Helper: `assert_audit_log_created(push, kind)` for audit log assertions
- Pre-commit hooks enforce RuboCop, ErbLint, and i18n normalization

---

## Coding Standards

- **RuboCop + ErbLint** enforced (Overcommit pre-commit hooks)
- **Hotwire/Stimulus** for JS interactivity, not React/Vue
- `optional: true` on all new `belongs_to` associations
- Inherit from **BaseController**, not ApplicationController
- New features must be behind a **feature flag** (`Settings.enable_xxx`)
- Use **Lockbox** (`has_encrypted`) for new sensitive data fields
- Settings go in `config/settings.yml` with `PWP__` env var overrides

---

## Feature Flag Reference

| Flag | Env Var | Default | Description |
|------|---------|---------|-------------|
| `enable_logins` | `PWP__ENABLE_LOGINS` | false | User accounts and authentication |
| `enable_user_policies` | `PWP__ENABLE_USER_POLICIES` | false | Per-user push default settings |
| `enable_two_factor` | `PWP__ENABLE_TWO_FACTOR` | false | TOTP two-factor authentication |
| `sso.google.enabled` | `PWP__SSO__GOOGLE__ENABLED` | false | Google OAuth2 login |
| `sso.microsoft.enabled` | `PWP__SSO__MICROSOFT__ENABLED` | false | Microsoft OAuth2 login |
| `enable_user_branding` | `PWP__ENABLE_USER_BRANDING` | false | Per-user branding on delivery pages |
| `enable_requests` | `PWP__ENABLE_REQUESTS` | false | Request/intake forms for submissions |
| `enable_teams` | `PWP__ENABLE_TEAMS` | false | Team collaboration |
| `enable_file_pushes` | `PWP__ENABLE_FILE_PUSHES` | false | File upload pushes (requires logins) |
| `enable_url_pushes` | `PWP__ENABLE_URL_PUSHES` | false | URL pushes (requires logins) |
| `enable_qr_pushes` | `PWP__ENABLE_QR_PUSHES` | false | QR code pushes (requires logins) |
| `allow_anonymous` | `PWP__ALLOW_ANONYMOUS` | true | Allow anonymous push creation |
| `disable_signups` | `PWP__DISABLE_SIGNUPS` | false | Prevent new user registration |
| `enable_audit_dashboard` | `PWP__ENABLE_AUDIT_DASHBOARD` | false | Centralized audit log dashboard |
| `enable_push_notifications` | `PWP__ENABLE_PUSH_NOTIFICATIONS` | false | Email notifications for push events |
| `enable_webhooks` | `PWP__ENABLE_WEBHOOKS` | false | Webhook HTTP POST notifications |
| `enable_ip_allowlisting` | `PWP__ENABLE_IP_ALLOWLISTING` | false | IP-based push access restriction |
| `enable_geofencing` | `PWP__ENABLE_GEOFENCING` | false | Country-based push access restriction |

---

## Pro Features Build Status

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Personal User Policy | COMPLETE |
| 2 | Two-Factor Authentication (2FA) | COMPLETE |
| 3 | SSO Login (Google & Microsoft) | COMPLETE |
| 4 | Per-User Branding & White-Label | COMPLETE |
| 5 | Request / Intake Forms | COMPLETE |
| 6 | Teams Foundation | COMPLETE |
| 7 | Team Policies & Configuration | COMPLETE |
| 8 | Team 2FA Enforcement | COMPLETE |
| 9 | GitHub Actions CI | COMPLETE |
| 10 | Docker Compose Dev | COMPLETE |
| 11 | Audit Dashboard + Push Notifications | COMPLETE |
| 12 | Webhook Notifications | COMPLETE |
| 13 | Broader API Coverage | COMPLETE |
| 14 | IP Allowlisting + Geofencing | COMPLETE |
| 15 | CLI Tool | COMPLETE |
| 16 | Admin Settings Panel + API | COMPLETE |
| 17 | User Account + 2FA + Notifications API | COMPLETE |
| 18 | Team Management API Gaps | COMPLETE |
| 19 | Swagger UI | COMPLETE |
| 20 | Organization Settings Hub | COMPLETE |
| 21 | Passphrase Password Generator | COMPLETE |
| 22 | Teams-Oriented Navigation & Polish | COMPLETE |

All features gated behind flags. 1110 tests, 4762 assertions, 0 failures.
CLI tool: 13 additional tests in `tools/cli/`.
Full details in `docs/app-build-progress.md`.
