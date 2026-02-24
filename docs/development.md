# Development Guide

Local development setup for PasswordPusher -- from clone to running tests.

## Prerequisites

| Tool    | Version / Notes                                                       |
|---------|-----------------------------------------------------------------------|
| Ruby    | 4.0.1 (see `.ruby-version`). Gemfile accepts `>= 3.4.3`.             |
| Node.js | Current LTS recommended.                                              |
| Yarn    | 1.x (classic). The repo pins `1.22.22` in `package.json`.            |
| SQLite3 | Development and test databases use SQLite by default.                 |
| Foreman | Installed automatically by `bin/dev` if missing.                      |

## Setup

### Quick start

```bash
bin/setup
```

This script:

1. Installs Bundler (if needed) and runs `bundle install`.
2. Runs `bin/rails db:prepare` (creates and migrates the SQLite database in `storage/db/`).
3. Clears old logs and temp files.
4. Restarts the application server.

### Manual alternative

```bash
gem install bundler --conservative
bundle install
yarn install
bin/rails db:prepare
```

## Running the App

```bash
bin/dev
```

`bin/dev` starts [Foreman](https://github.com/ddollar/foreman) with `Procfile.dev`, which launches four processes:

| Process  | Command                              | Purpose                         |
|----------|--------------------------------------|---------------------------------|
| `web`    | `bin/rails server -p 5100`           | Rails app on port 5100          |
| `worker` | `bundle exec rake solid_queue:start` | Background job processor        |
| `css`    | `yarn build:css --watch`             | Sass/PostCSS compilation + watch|
| `js`     | `yarn build --watch`                 | esbuild JS bundling + watch     |

After startup, open [http://localhost:5100](http://localhost:5100).

## Configuration

PasswordPusher uses the [Config gem](https://github.com/rubyconfig/config) for settings.

### Hierarchy (highest wins)

1. **Environment variables** with `PWP__` prefix (double underscore separates nesting levels).
2. **`config/settings.local.yml`** -- gitignored, per-developer overrides.
3. **`config/settings.yml`** -- checked-in defaults.

### Environment variable mapping

Nested YAML keys become `PWP__` env vars with `__` separators:

```
# settings.yml           -> env var
pw:
  expire_after_days_max  -> PWP__PW__EXPIRE_AFTER_DAYS_MAX=90
mail:
  smtp_port              -> PWP__MAIL__SMTP_PORT=587
```

See `.env.example` at the project root for every available variable with descriptions.

### Local overrides

For development, create `config/settings.local.yml` (gitignored) to override any setting:

```yaml
enable_logins: true
enable_file_pushes: true
```

Or use a `.env` file (also gitignored, loaded by the `dotenv` gem).

## Feature Flags

All flags default to `false` unless noted. Set via `config/settings.yml`, `settings.local.yml`, or env vars.

| Flag                         | Env var                        | Description                                                  |
|------------------------------|--------------------------------|--------------------------------------------------------------|
| `enable_logins`              | `PWP__ENABLE_LOGINS`           | User accounts. Requires SMTP.                                |
| `allow_anonymous`            | `PWP__ALLOW_ANONYMOUS`         | Anonymous push creation. Default: **true**.                   |
| `disable_signups`            | `PWP__DISABLE_SIGNUPS`         | Block new registrations (existing accounts kept).             |
| `enable_user_policies`       | `PWP__ENABLE_USER_POLICIES`    | Per-user default push settings.                              |
| `enable_two_factor`          | `PWP__ENABLE_TWO_FACTOR`       | TOTP-based 2FA for user accounts.                            |
| `enable_user_branding`       | `PWP__ENABLE_USER_BRANDING`    | Per-user branding on delivery pages.                         |
| `enable_requests`            | `PWP__ENABLE_REQUESTS`         | Request / intake forms for third-party submissions.          |
| `enable_teams`               | `PWP__ENABLE_TEAMS`            | Team collaboration with roles and shared pushes.             |
| `enable_url_pushes`          | `PWP__ENABLE_URL_PUSHES`       | URL-based pushes. Requires `enable_logins`.                  |
| `enable_file_pushes`         | `PWP__ENABLE_FILE_PUSHES`      | File upload pushes. Requires `enable_logins` + storage.      |
| `enable_qr_pushes`           | `PWP__ENABLE_QR_PUSHES`        | QR code pushes. Requires `enable_logins`.                    |
| `sso.google.enabled`         | `PWP__SSO__GOOGLE__ENABLED`    | Google OAuth2 login.                                         |
| `sso.microsoft.enabled`      | `PWP__SSO__MICROSOFT__ENABLED` | Microsoft OAuth2 login.                                      |

## Testing

PasswordPusher uses **Minitest** with Rails fixtures.

### Run the full suite

```bash
bin/rails test
```

The project contains approximately 151 test files under `test/`.

### Run a single file or test

```bash
bin/rails test test/integration/password_push_test.rb
bin/rails test test/integration/password_push_test.rb:42
```

### Test environment notes

- `test_helper.rb` strips all `PWP__*` environment variables before each run to prevent local config from leaking into tests.
- Fixtures live in `test/fixtures/*.yml` and are loaded for all test classes via `fixtures :all`.
- Devise integration helpers are included in `ActionDispatch::IntegrationTest`.

## Linting & Static Analysis

The project uses [Overcommit](https://github.com/sds/overcommit) for pre-commit hooks. Install hooks with:

```bash
bundle exec overcommit --install
```

### Active pre-commit hooks

| Hook                        | Tool           | Scope                         |
|-----------------------------|----------------|-------------------------------|
| RuboCop                     | `rubocop`      | Ruby style/lint               |
| ErbLint                     | `erblint`      | ERB template lint             |
| I18nTasksNormalize          | `i18n-tasks`   | Locale YAML normalization     |
| AutoFixTrailingWhitespace   | `sed`          | Trailing whitespace in `*.rb`, `*.yml` |

### Run linters manually

```bash
bundle exec rubocop                  # Ruby style
bundle exec erblint --lint-all       # ERB templates
bundle exec i18n-tasks normalize     # Locale files
bundle exec brakeman                 # Security analysis
```

## Email in Development

The app includes the [Mailbin](https://github.com/pglombardo/mailbin) gem in the development group. When `enable_logins` is `true`, outgoing emails are captured and viewable at:

```
http://localhost:5100/mailbin
```

No external SMTP server is needed for development.

## Database Alternatives

By default, development uses SQLite stored at `storage/db/development.sqlite3`.

### PostgreSQL

```bash
DATABASE_URL='postgres://user:pass@localhost:5432/pwpush_dev' bin/dev
```

### MySQL / MariaDB

```bash
DATABASE_URL='mysql2://user:pass@localhost:3306/pwpush_dev' bin/dev
```

Both `pg` and `mysql2` gems are included in the Gemfile. The connection pool size is controlled by `DB_POOL` or `RAILS_MAX_THREADS` (default: 5).

## Key Encryption

Push payloads are encrypted at rest with [Lockbox](https://github.com/ankane/lockbox). In development, a default master key is used automatically. For production, always set `PWPUSH_MASTER_KEY`. See the Lockbox initializer at `config/initializers/lockbox.rb` for details.

## Further Reading

- [docs/architecture.md](architecture.md) -- system architecture and code layout.
- [.env.example](../.env.example) -- complete environment variable reference.
- [config/settings.yml](../config/settings.yml) -- annotated default settings with inline documentation.
- [Official docs](https://docs.pwpush.com/) -- full PasswordPusher documentation.
