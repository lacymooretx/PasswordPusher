# PasswordPusher Architecture

Reference document for the PasswordPusher codebase. Covers the stack, domain model, request lifecycle, settings resolution, and major subsystems.

---

## Stack Summary

| Component         | Technology                                                    |
|-------------------|---------------------------------------------------------------|
| Framework         | Rails 8.1.1                                                   |
| Ruby              | >= 3.4.3 (configurable via `CUSTOM_RUBY_VERSION`)             |
| Authentication    | Devise 5.0 (database_authenticatable, registerable, recoverable, rememberable, validatable, trackable, confirmable, lockable, timeoutable, omniauthable) |
| 2FA               | ROTP 6.3 (TOTP) with BCrypt backup codes                     |
| SSO               | OmniAuth (Google OAuth2, Microsoft Graph)                     |
| Encryption        | Lockbox (AES-GCM via `PWPUSH_MASTER_KEY`)                    |
| Configuration     | Config gem (`config/settings.yml`), env var overrides (`PWP__*`) |
| Database          | SQLite (dev default), PostgreSQL (`pg`), MySQL (`mysql2`)     |
| Background Jobs   | Solid Queue (recurring schedule in `config/recurring.yml`)    |
| Cache             | Solid Cache                                                    |
| WebSocket         | Solid Cable                                                    |
| Asset Pipeline    | Propshaft, cssbundling-rails, jsbundling-rails, importmap-rails |
| CSS               | Bootstrap 5 with Bootswatch themes, sass-embedded             |
| JavaScript        | Stimulus.js, Turbo (turbo-rails)                              |
| API Docs          | Apipie-rails                                                   |
| Pagination        | Kaminari                                                       |
| Throttling        | Rack::Attack                                                   |
| Error Tracking    | Rollbar                                                        |
| File Storage      | ActiveStorage (local, Amazon S3, Minio, Google Cloud, Azure)  |
| QR Codes          | rqrcode                                                        |
| Admin             | Madmin, MissionControl::Jobs                                  |
| Deployment        | Kamal, Thruster, Puma, Foreman/Overmind                       |
| Logging           | Lograge                                                        |
| Testing           | Minitest, Capybara, Selenium                                  |
| i18n              | Translation.io, devise-i18n, rails-i18n                       |
| Maintenance Mode  | Turnout (turnout2024 gem)                                     |

---

## Push Lifecycle

A "push" is a shared secret with automatic expiration. The full lifecycle:

### 1. Creation

- `PushesController#new` builds a blank `Push` and selects the active tab (text/file/url/qr) based on the `tab` query parameter.
- `PushesController#create` instantiates the push with permitted params, assigns the current user (if signed in), and delegates boolean attribute handling to the `SetPushAttributes` concern (`assign_deletable_by_viewer`, `assign_retrieval_step`).
- Before validation callbacks on `Push` fire in order:
  1. `set_expire_limits` -- resolves `expire_after_days` and `expire_after_views` through the settings chain (see Settings Resolution below), clamping to global min/max.
  2. `set_url_token` -- generates a random URL-safe Base64 token (`SecureRandom.urlsafe_base64(rand(8..14))`).
  3. `set_default_attributes` -- defaults `note`, `passphrase`, and `name` to empty strings.
- Kind-specific validators run: `check_payload_for_text`, `check_files_for_file`, `check_payload_for_url`, `check_payload_for_qr`.
- On success, the `LogEvents` concern records a `:creation` audit log entry. User is redirected to the preview page.

File: `app/controllers/pushes_controller.rb`, `app/models/push.rb`

### 2. Preview

- `PushesController#preview` generates the secret URL and QR code for sharing.
- `PushesController#print_preview` renders a printable version with optional message and expiration info (layout: `naked`).

### 3. Retrieval (Show)

- `PushesController#show` is the public-facing retrieval endpoint.
- Calls `@push.check_limits` to expire the push if days or views are exhausted.
- If expired, logs a `:failed_view` and renders `show_expired` (layout: `naked`).
- If a passphrase is set, checks for the passphrase in params or a short-lived cookie. On mismatch, redirects to the passphrase page.
- Logs a `:view` (or `:owner_view` / `:admin_view` for non-counting views).
- For URL pushes, issues a 303 redirect to the target URL.
- For other kinds, renders with optional blur CSS class (layout: `bare`).
- After rendering, if this was the last allowed view and no files are attached, calls `@push.expire!` immediately.

### 4. Retrieval Step (Preliminary)

- When `retrieval_step` is true, the secret URL path is `/p/:url_token/r` which renders a "click to reveal" interstitial page (layout: `naked`) before redirecting to the actual show page.

### 5. Passphrase Protection

- `PushesController#passphrase` renders the passphrase entry form (layout: `naked`).
- `PushesController#access` validates the passphrase using `ActiveSupport::SecurityUtils.secure_compare`, sets a 3-minute httponly cookie containing the ciphertext, and redirects to show. On failure, logs `:failed_passphrase`.

### 6. Expiration

- **Automatic (time/views):** `Push#check_limits` expires when `days_remaining` or `views_remaining` hit zero. Called on every show request and by `ExpirePushesJob`.
- **Manual (viewer):** `PushesController#expire` allows deletion if `deletable_by_viewer` is true or the user is the owner. Logs `:expire`.
- **Expiration action:** `Push#expire` / `Push#expire!` nullifies `payload`, `passphrase`, purges attached files, sets `expired: true` and `expired_on`.

### 7. Cleanup (Background)

- `CleanUpPushesJob` destroys expired anonymous push records entirely (no user_id).
- `PurgeExpiredPushesJob` destroys expired pushes older than `Settings.purge_after` (configurable duration).
- `PurgeUnattachedBlobsJob` purges orphaned ActiveStorage blobs.
- Non-existent URL tokens render the expired page to avoid information leakage about whether a push ever existed.

---

## Push Kinds

Defined as a Rails integer enum on `Push`:

```ruby
enum :kind, [:text, :file, :url, :qr], validate: true
```

| Kind   | Enum value | Feature flag                                  | Settings key   | Route prefix | Notes                                      |
|--------|-----------|-----------------------------------------------|----------------|-------------|---------------------------------------------|
| `text` | 0         | Always enabled (anonymous allowed via `allow_anonymous`) | `Settings.pw`    | `/p/`        | Default kind; 1 MB max payload              |
| `file` | 1         | `enable_logins` AND `enable_file_pushes`      | `Settings.files` | `/p/` (was `/f/`) | Requires login; ActiveStorage attachments; max file count configurable |
| `url`  | 2         | `enable_logins` AND `enable_url_pushes`       | `Settings.url`   | `/p/` (was `/r/`) | Requires login; validated via Addressable::URI; show redirects to URL |
| `qr`   | 3         | `enable_logins` AND `enable_qr_pushes`        | `Settings.qr`    | `/p/`        | Requires login; 1024 byte max payload       |

Legacy `/f/` and `/r/` routes 301-redirect to `/p/` equivalents.

Each kind has per-kind settings in `config/settings.yml` under the corresponding key (`pw`, `url`, `files`, `qr`):
- `expire_after_days_default`, `_min`, `_max`
- `expire_after_views_default`, `_min`, `_max`
- `enable_retrieval_step`, `retrieval_step_default`
- `enable_deletable_pushes`, `deletable_pushes_default` (not on URL kind)
- `enable_blur` (text and file only)
- `max_file_uploads` (file kind only)

The `Push#settings_for_kind` method maps the enum to the corresponding `Settings.*` object.

File: `app/models/push.rb` (lines 199-209)

---

## Settings Resolution Chain

When a push is created, expiration and behavior defaults are resolved through a priority chain. The highest-priority non-nil value wins:

```
Team Forced  >  Team Default  >  User Policy  >  Global Settings
```

### Resolution logic (Push#resolve_setting)

```
1. team_policy_forced_value(attribute)  -- if team exists, Settings.enable_teams, and the team forces this setting
2. team_policy_default(attribute)       -- if team exists and has a non-forced default
3. user_policy_default(attribute)       -- if Settings.enable_user_policies and user has a UserPolicy record
4. settings_for_kind.send("#{attribute}_default")  -- global default from config/settings.yml
```

- **Team forced** values override everything, including what the user submitted in the form (checked via `team_forces?` in `set_expire_limits`).
- **User Policy** defaults are stored as per-kind columns in `UserPolicy` (e.g., `pw_expire_after_days`, `url_expire_after_views`). UserPolicy validates values against global min/max.
- **Global Settings** come from `config/settings.yml` and can be overridden by environment variables using the `PWP__` prefix (e.g., `PWP__PW__EXPIRE_AFTER_DAYS_DEFAULT=7`).
- After resolution, values are clamped to `[min, max]` range. Out-of-range values fall back to the global default.

The boolean attributes `deletable_by_viewer` and `retrieval_step` are resolved separately in the `SetPushAttributes` concern because HTML checkbox semantics require special handling (unchecked = absent from params).

Files:
- `app/models/push.rb` (lines 231-295) -- `resolve_setting`, `team_forces?`, `user_policy_default`
- `app/controllers/concerns/set_push_attributes.rb` -- `assign_deletable_by_viewer`, `assign_retrieval_step`
- `app/models/user_policy.rb` -- `default_for(kind, attribute)`
- `app/models/team.rb` (lines 59-102) -- `policy_default`, `policy_forced?`, `policy_forced_value`
- `config/settings.yml` -- global defaults, min/max ranges

---

## Controller Hierarchy

```
ActionController::Base
  |
  +-- ApplicationController              # app/controllers/application_controller.rb
  |     includes: SetLocale
  |     - CSRF protection (skip for JSON)
  |     - Flash types: info, error, success, warning
  |     - Devise parameter sanitization
  |
  +---- BaseController                   # app/controllers/base_controller.rb
  |       includes: TeamTwoFactorEnforcement
  |       - Rescues ParameterMissing, UnknownFormat, BadRequest
  |       - All feature controllers inherit from this
  |
  +------ PushesController               # app/controllers/pushes_controller.rb
  |         includes: SetPushAttributes, LogEvents
  |         - Full CRUD for pushes plus passphrase, preview, audit, expire
  |
  +------ RequestsController             # app/controllers/requests_controller.rb
  +------ RequestSubmissionsController    # app/controllers/request_submissions_controller.rb
  +------ TeamsController                 # app/controllers/teams_controller.rb
  +------ MembershipsController           # app/controllers/memberships_controller.rb
  +------ TeamInvitationsController       # app/controllers/team_invitations_controller.rb
  +------ TeamPoliciesController          # app/controllers/team_policies_controller.rb
  +------ TeamTwoFactorController         # app/controllers/team_two_factor_controller.rb
  +------ UserPoliciesController          # app/controllers/user_policies_controller.rb
  +------ UserBrandingsController         # app/controllers/user_brandings_controller.rb
  +------ AdminController                 # app/controllers/admin_controller.rb
  +------ Admin::UsersController          # app/controllers/admin/users_controller.rb
  |
  +---- Api::BaseController              # app/controllers/api/base_controller.rb
  |       - Token-based authentication (Bearer token or X-User-Token header)
  |       - Inherits from ApplicationController (not BaseController)
  |       - Public endpoints: version, push show/create (anonymous)
  |       - Protected endpoints: audit, active, expired, user_policies
  |
  +------ Api::V1::PushesController      # app/controllers/api/v1/pushes_controller.rb
  +------ Api::V1::UserPoliciesController # app/controllers/api/v1/user_policies_controller.rb
  +------ Api::V1::VersionController      # app/controllers/api/v1/version_controller.rb
  |
  +---- Devise Controllers (under users/)
          sessions, registrations, passwords, confirmations, unlocks,
          omniauth_callbacks, two_factor, two_factor_verification
```

### Controller Concerns

| Concern                     | File                                              | Included by         | Purpose                                                           |
|-----------------------------|---------------------------------------------------|---------------------|-------------------------------------------------------------------|
| `SetLocale`                 | `app/controllers/concerns/set_locale.rb`          | ApplicationController | Locale resolution: params > user preference > Accept-Language header > default |
| `TeamTwoFactorEnforcement`  | `app/controllers/concerns/team_two_factor_enforcement.rb` | BaseController | Redirects users to 2FA setup if any team requires it              |
| `SetPushAttributes`         | `app/controllers/concerns/set_push_attributes.rb` | PushesController    | Boolean attribute handling for `deletable_by_viewer` and `retrieval_step` with HTML/JSON differences |
| `LogEvents`                 | `app/controllers/concerns/log_events.rb`          | PushesController    | Audit log creation for view, creation, update, expire, failed_passphrase events. Distinguishes admin_view and owner_view (non-counting) |

### Model Concerns

| Concern                       | File                                                  | Included by | Purpose                                           |
|-------------------------------|-------------------------------------------------------|-------------|---------------------------------------------------|
| `Pwpush::TokenAuthentication` | `app/models/concerns/pwpush/token_authentication.rb`  | User        | API token generation, regeneration, and purging using `Devise.friendly_token` |

---

## Model Relationships

```
User
  |-- has_many :pushes
  |-- has_many :requests
  |-- has_one  :user_policy
  |-- has_one  :user_branding
  |-- has_many :otp_backup_codes
  |-- has_many :memberships
  |-- has_many :teams, through: :memberships
  |-- has_many :owned_teams (as owner)

Push
  |-- belongs_to :user (optional)
  |-- belongs_to :request (optional)
  |-- belongs_to :team (optional)
  |-- has_many   :audit_logs
  |-- has_many_attached :files (ActiveStorage)

AuditLog
  |-- belongs_to :push
  |-- belongs_to :user (optional)
  |   enum :kind => [:creation, :view, :failed_view, :expire,
  |                   :failed_passphrase, :admin_view, :owner_view, :edit]

Team
  |-- belongs_to :owner (User)
  |-- has_many   :memberships
  |-- has_many   :users, through: :memberships
  |-- has_many   :team_invitations
  |-- has_many   :pushes

Membership
  |-- belongs_to :team
  |-- belongs_to :user
  |   enum :role => { member: 0, admin: 1, owner: 2 }

TeamInvitation
  |-- belongs_to :team
  |-- belongs_to :invited_by (User)
  |   enum :role => { member: 0, admin: 1 }
  |   States: pending, expired, accepted

Request
  |-- belongs_to :user
  |-- has_many   :pushes

UserPolicy
  |-- belongs_to :user
  |   Per-kind columns: {pw,url,file,qr}_{expire_after_days,expire_after_views,retrieval_step,deletable_by_viewer}

UserBranding
  |-- belongs_to :user
  |-- has_one_attached :logo

OtpBackupCode
  |-- belongs_to :user
  |   Stores BCrypt digest; one-time use

DataMigrationStatus
  |   Standalone; tracks completed data migrations by name
```

---

## Authentication and Security

### Devise Modules

Configured on `User` (`app/models/user.rb`):

`database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`, `trackable`, `confirmable`, `lockable`, `timeoutable`, `omniauthable`

Session timeout is configurable via `Settings.login_session_timeout` (default: 2 hours). Signups can be disabled (`Settings.disable_signups`) or restricted by email domain regex (`Settings.signup_email_regexp`).

### API Token Authentication

- `Api::BaseController` (`app/controllers/api/base_controller.rb`) extracts tokens from `Authorization: Bearer <token>` header or legacy `X-User-Token` header.
- Tokens are generated via `Pwpush::TokenAuthentication` concern using `Devise.friendly_token`.
- Managed at `/users/token` (view/regenerate/delete).
- Public API endpoints (push create/show, version) do not require a token for anonymous text pushes.

### Two-Factor Authentication (2FA)

Feature flag: `Settings.enable_two_factor`

- TOTP-based using the `rotp` gem. The `otp_secret` is encrypted at rest via Lockbox.
- Drift tolerance: +/- 15 seconds. Replay prevention via `consumed_timestep`.
- Backup codes: 10 codes generated as 8-character hex strings, stored as BCrypt digests (`OtpBackupCode`). One-time use.
- Team enforcement: Teams can set `require_two_factor: true`. The `TeamTwoFactorEnforcement` concern redirects users without 2FA to the setup page.
- Routes: `config/routes/two_factor.rb` -- setup, enable, disable, regenerate_backup_codes, verification.

### SSO (Single Sign-On)

Feature flags: `Settings.sso.google.enabled`, `Settings.sso.microsoft.enabled`

- OmniAuth providers: `omniauth-google-oauth2`, `omniauth-microsoft_graph`
- CSRF protection: `omniauth-rails_csrf_protection`
- `User.from_omniauth(auth)` links by provider+uid first, then by email (merges SSO into existing account), then creates a new pre-confirmed user.
- Controller: `app/controllers/users/omniauth_callbacks_controller.rb`

### Lockbox Encryption

Master key: `PWPUSH_MASTER_KEY` environment variable (fallback to a default key).
Supports key rotation via `PWPUSH_MASTER_KEY_PREVIOUS` (comma-separated list).

Encrypted fields:
- `Push`: `payload`, `note`, `passphrase` (stored as `*_ciphertext` columns)
- `User`: `otp_secret`

File: `config/initializers/lockbox.rb`

### Additional Security

- **CSRF**: Enabled for HTML, disabled for JSON (`protect_from_forgery unless: -> { request.format.json? }`)
- **Throttling**: Rack::Attack with configurable per-second and per-minute limits (`config/initializers/rack_attack.rb`)
- **CSP**: Content Security Policy reporting endpoint at `/csp-violation-report`
- **Secure Cookies**: Optional via `Settings.secure_cookies` (HTTPS-only, httponly, SameSite)
- **Invisible Captcha**: `invisible_captcha` gem for bot protection
- **Passphrase comparison**: Uses `ActiveSupport::SecurityUtils.secure_compare` to prevent timing attacks

---

## Routes

Routes are split across files in `config/routes/` using Rails `draw` DSL. The main `config/routes.rb` conditionally loads route sets based on mode.

### Gateway Mode

When `ENV["PWP_PUBLIC_GATEWAY"]` is set, only public push retrieval and user routes are loaded (no creation, no admin). Root returns 404. This supports a split deployment where creation happens on an internal instance.

Route files loaded in gateway mode: `public_users.rb`, `public_pushes.rb`

### Standard Mode Route Files

| File                  | Purpose                                                         |
|-----------------------|-----------------------------------------------------------------|
| `admin.rb`            | Admin dashboard, user management (promote/revoke/destroy), MissionControl::Jobs mount. Requires admin role. |
| `madmin.rb`           | Madmin auto-admin interface mount                               |
| `users.rb`            | Devise routes (sessions, registrations, passwords, confirmations, unlocks) with optional signup disable. Token management. |
| `pushes.rb`           | Main push CRUD: `/p/:url_token` with preview, print_preview, passphrase, access, preliminary, expire, audit, delete_file. Legacy `/f/` and `/r/` redirects. |
| `user_policies.rb`    | `resource :user_policy, only: [:edit, :update]`                 |
| `two_factor.rb`       | 2FA setup/enable/disable/regenerate under `users/two_factor`, plus verification |
| `user_brandings.rb`   | `resource :user_branding, only: [:edit, :update]`               |
| `requests.rb`         | Request CRUD plus public intake form (`/req/:url_token`)        |
| `teams.rb`            | Team CRUD, nested memberships, invitations, policy, two_factor. Public invitation acceptance. |
| `pwp_api.rb`          | JSON API (format constrained). Namespaced `api/v1` for version and user_policies. Push endpoints at `/p/`, `/f/`, `/r/` with conditionals for enabled features. |
| `redirects.rb`        | API token path redirect                                         |
| `legacy_devise.rb`    | Legacy Devise route redirects                                   |
| `legacy_pages.rb`     | Legacy page redirects                                           |
| `legacy_pushes.rb`    | Localized legacy push URLs redirect to current paths. Per-locale translated route names. |

### Key Route Paths

- Root: `pushes#new` (push creation form)
- Push show: `GET /p/:url_token`
- Push retrieval step: `GET /p/:url_token/r`
- Push passphrase: `GET /p/:url_token/passphrase`
- Push API: `POST /p.json` (create), `GET /p/:url_token.json` (show)
- Health check: `GET /up`
- Static pages: `GET /pages/*id` (HighVoltage)
- Apipie docs: mounted via `apipie`
- Mailbin (dev only): mounted at `/mailbin`

---

## Frontend

### Stimulus Controllers

Located in `app/javascript/controllers/`:

| Controller            | File                       | Purpose                                                    |
|-----------------------|----------------------------|------------------------------------------------------------|
| `application`         | `application.js`           | Stimulus application bootstrap                             |
| `copy_controller`     | `copy_controller.js`       | Copy-to-clipboard for secret URLs and payloads             |
| `countdown_controller`| `countdown_controller.js`  | Countdown timer display for push expiration                |
| `form_controller`     | `form_controller.js`       | Push creation form interactions (tab switching, validation)|
| `gdpr_controller`     | `gdpr_controller.js`       | GDPR cookie consent banner behavior                        |
| `knobs_controller`    | `knobs_controller.js`      | Range slider controls for expiration settings              |
| `multi_upload_controller` | `multi_upload_controller.js` | Multiple file upload handling for file pushes          |
| `passwords_controller`| `passwords_controller.js`  | Password reveal/blur toggle on show page                   |
| `pwgen_controller`    | `pwgen_controller.js`      | Client-side password generator                             |
| `theme_controller`    | `theme_controller.js`      | Light/dark theme switching                                 |

Index file: `app/javascript/controllers/index.js`

### Turbo

Turbo Drive is enabled via `turbo-rails` for SPA-like page transitions. Turbo Stream is configured for Devise navigation (`config/initializers/devise.rb`).

### Themes

Bootstrap 5 with Bootswatch theme support. Theme is controlled by `PWP__THEME` environment variable. Available themes include: cerulean, cosmo, cyborg, darkly, flatly, journal, litera, lumen, lux, materia, minty, morph, pulse, quartz, sandstone, simplex, sketchy, slate, solar, spacelab, superhero, united, vapor, yeti, zephyr.

### Layouts

Located in `app/views/layouts/`:

| Layout              | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `application.html.erb` | Full layout with navigation, footer, flash messages         |
| `bare.html.erb`     | Minimal layout for push show pages (payload display)           |
| `naked.html.erb`    | Stripped layout for expired pages, passphrase entry, preliminary, print preview |
| `login.html.erb`    | Layout for authentication pages                                |
| `admin.html.erb`    | Admin dashboard layout                                         |
| `mailer.html.erb`   | HTML email layout                                              |
| `mailer.text.erb`   | Plain text email layout                                        |

### User Branding

When `Settings.enable_user_branding` is true, push delivery pages (`show`, `preliminary`, `passphrase`) load the push owner's `UserBranding` record to apply custom logo, colors, heading, message, footer, and optional white-label mode.

---

## Background Jobs

Powered by Solid Queue. Schedule defined in `config/recurring.yml`.

| Job                      | Schedule (production)          | Purpose                                                    |
|--------------------------|--------------------------------|------------------------------------------------------------|
| `ExpirePushesJob`        | Every 2 hours                  | Scans all unexpired pushes, calls `check_limits` to expire those past their days or views limit |
| `CleanUpPushesJob`       | Daily at 5am                   | Destroys expired anonymous pushes (no `user_id`) to minimize stored data |
| `PurgeExpiredPushesJob`  | Daily at 4am                   | Destroys all expired pushes older than `Settings.purge_after` (disabled by default) |
| `PurgeUnattachedBlobsJob`| Every 3 days                   | Purges orphaned ActiveStorage blobs via `bin/pwpush active_storage:purge_unattached` |
| `CleanupCacheJob`        | Daily at 3am                   | Removes cache files older than 24 hours from `tmp/cache` and `tmp/rack_attack_cache` |
| (inline)                 | Every hour at minute 12        | `SolidQueue::Job.clear_finished_in_batches` -- cleans up completed Solid Queue records |

Jobs log to `log/recurring.log` (or STDOUT if `PWP_WORKER` env var is set for container deployments).

File: `app/jobs/`, `config/recurring.yml`

---

## i18n (Internationalization)

### Supported Languages

35 languages enabled by default, configured in `Settings.enabled_language_codes`:

ca, cs, cy, da, de, en, en-GB, es, eu, fi, fr, ga, hi, hu, id, is, it, ja, ko, lv, nl, no, pl, pt-BR, pt-PT, ro, ru, sr, sk, sv, th, uk, ur, zh-CN

Default locale: `en` (configurable via `Settings.default_locale` / `PWP__DEFAULT_LOCALE`).

### Translation Files

Located in `config/locales/`:

- `en.yml` -- base English translations
- `devise.en.yml` -- Devise-specific English translations
- `translation.*.yml` -- app translations per language (managed by Translation.io)
- `localization.*.yml` -- date/time/number format locales per language
- `config/locales/gettext/` -- gettext-style translation catalog

### Locale Resolution

Handled by `SetLocale` concern (`app/controllers/concerns/set_locale.rb`):

```
1. params[:locale]              -- explicit URL parameter
2. current_user.preferred_language  -- user preference (if signed in)
3. HTTP Accept-Language header   -- browser preference
4. I18n.default_locale           -- fallback
```

### Translation.io Integration

The `translation` gem syncs translations with Translation.io service. Configured in `config/initializers/translation.rb`. The codebase uses `I18n._()` for gettext-style translation calls alongside standard `I18n.t()`.

---

## Feature Flags

All major features are gated behind boolean settings in `config/settings.yml` with environment variable overrides:

| Flag                      | Env Var                        | Default | Controls                             |
|---------------------------|--------------------------------|---------|--------------------------------------|
| `enable_logins`           | `PWP__ENABLE_LOGINS`           | false   | User accounts, required for non-text pushes |
| `enable_file_pushes`      | `PWP__ENABLE_FILE_PUSHES`      | false   | File push kind                       |
| `enable_url_pushes`       | `PWP__ENABLE_URL_PUSHES`       | false   | URL push kind                        |
| `enable_qr_pushes`        | `PWP__ENABLE_QR_PUSHES`        | false   | QR code push kind                    |
| `enable_user_policies`    | `PWP__ENABLE_USER_POLICIES`    | false   | Per-user push defaults               |
| `enable_two_factor`       | `PWP__ENABLE_TWO_FACTOR`       | false   | TOTP 2FA                             |
| `sso.google.enabled`      | `PWP__SSO__GOOGLE__ENABLED`    | false   | Google SSO                           |
| `sso.microsoft.enabled`   | `PWP__SSO__MICROSOFT__ENABLED` | false   | Microsoft SSO                        |
| `enable_user_branding`    | `PWP__ENABLE_USER_BRANDING`    | false   | Per-user delivery page branding      |
| `enable_requests`         | `PWP__ENABLE_REQUESTS`         | false   | Intake/request forms                 |
| `enable_teams`            | `PWP__ENABLE_TEAMS`            | false   | Team collaboration                   |
| `allow_anonymous`         | `PWP__ALLOW_ANONYMOUS`         | true    | Anonymous push creation (text only)  |
| `disable_signups`         | `PWP__DISABLE_SIGNUPS`         | false   | Block new user registration          |
