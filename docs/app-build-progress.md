# PasswordPusher Pro Features — Build Progress

## Phase Overview

| Phase | Feature | Status | Started | Completed |
|-------|---------|--------|---------|-----------|
| 1 | Personal User Policy | COMPLETE | 2026-02-24 | 2026-02-24 |
| 2 | Two-Factor Authentication (2FA) | COMPLETE | 2026-02-24 | 2026-02-24 |
| 3 | SSO Login (Google & Microsoft) | COMPLETE | 2026-02-24 | 2026-02-24 |
| 4 | Per-User Branding & White-Label | COMPLETE | 2026-02-24 | 2026-02-24 |
| 5 | Request / Intake Forms | COMPLETE | 2026-02-24 | 2026-02-24 |
| 6 | Teams Foundation | COMPLETE | 2026-02-24 | 2026-02-24 |
| 7 | Team Policies & Configuration | COMPLETE | 2026-02-24 | 2026-02-24 |
| 8 | Team 2FA Enforcement | COMPLETE | 2026-02-24 | 2026-02-24 |
| 9 | GitHub Actions CI | COMPLETE | 2026-02-24 | 2026-02-24 |
| 10 | Docker Compose Dev | COMPLETE | 2026-02-24 | 2026-02-24 |
| 11 | Audit Dashboard + Push Notifications | COMPLETE | 2026-02-24 | 2026-02-24 |
| 12 | Webhook Notifications | COMPLETE | 2026-02-24 | 2026-02-24 |
| 13 | Broader API Coverage | COMPLETE | 2026-02-24 | 2026-02-24 |
| 14 | IP Allowlisting + Geofencing | COMPLETE | 2026-02-24 | 2026-02-24 |
| 15 | CLI Tool | COMPLETE | 2026-02-24 | 2026-02-24 |
| 16 | Admin Settings Panel + API | COMPLETE | 2026-02-25 | 2026-02-25 |
| 17 | User Account + 2FA + Notifications API | COMPLETE | 2026-02-25 | 2026-02-25 |
| 18 | Team Management API Gaps | COMPLETE | 2026-02-25 | 2026-02-25 |
| 19 | Swagger UI | COMPLETE | 2026-02-25 | 2026-02-25 |
| 20 | Organization Settings Hub | COMPLETE | 2026-02-25 | 2026-02-25 |
| 21 | Passphrase Password Generator | COMPLETE | 2026-02-25 | 2026-02-25 |
| 22 | Teams-Oriented Navigation & Polish | COMPLETE | 2026-02-25 | 2026-02-25 |

---

## Phase 22: Teams-Oriented Navigation & Polish

### Goal
Make the app feel teams-oriented by updating main navigation with top-level Pushes/Requests links, adding a team context switcher, refreshing the team index page, and enhancing the footer with configurable links.

### Deliverables
- [x] `app/views/shared/_header.html.erb` — redesigned with top-level Pushes/Requests nav, team switcher dropdown, slimmed account dropdown with Bootstrap Icons
- [x] `app/views/teams/index.html.erb` — refreshed cards with team avatars, role badges, member counts, 2FA indicators, quick-action buttons
- [x] `app/views/shared/_footer.html.erb` — added API Documentation link, configurable Best Practices/Help/Privacy/Terms links
- [x] `config/settings.yml` + `config/defaults/settings.yml` — added `brand.help_url`, `brand.privacy_url`, `brand.terms_url`, `brand.best_practices_url` (byte-identical)
- [x] `test/integration/navigation_test.rb` — 9 tests for header nav, team switcher, footer links

### Verification
- 1110 tests, 4762 assertions, 0 failures
- ERB lint: 0 errors on modified files
- Settings files byte-identical: confirmed

---

## Phase 21: Passphrase Password Generator

### Goal
Replace the default syllable-based password generator with an EFF Diceware passphrase generator using cryptographically secure randomness.

### Deliverables
- [x] `app/javascript/lib/eff_wordlist.js` — 7776-word EFF Large Wordlist (public domain)
- [x] `app/javascript/controllers/pwgen_controller.js` — passphrase mode, mode switching, cookie persistence
- [x] `app/views/shared/_pw_generator_modal.html.erb` — mode selector UI, passphrase options panel, syllable options panel
- [x] `app/views/pushes/_form.html.erb` — new passphrase default data attributes
- [x] `app/views/pushes/_qr_form.html.erb` — new passphrase default data attributes
- [x] `config/settings.yml` + `config/defaults/settings.yml` — 5 new `gen.passphrase_*` settings

### Settings Added
| Setting | Default | Description |
|---------|---------|-------------|
| `gen.mode` | `passphrase` | Generation mode: `passphrase` or `syllable` |
| `gen.passphrase_word_count` | `4` | Number of words |
| `gen.passphrase_separator` | `-` | Word separator |
| `gen.passphrase_capitalize` | `true` | Capitalize each word |
| `gen.passphrase_include_number` | `true` | Append random digit |

### Verification
- Settings verified via `rails runner`: all 5 new values load correctly
- JavaScript builds cleanly (602.7kb bundle, EFF wordlist bundled)
- ErbLint: 0 errors on changed views
- Syllable mode preserved and accessible via mode radio button

---

## Phase 1: Personal User Policy

### Goal
Per-user default settings for expiration, retrieval step, deletable-by-viewer.

### Deliverables
- [x] Migration: `create_user_policies` table
- [x] Model: `UserPolicy` with validations
- [x] Model: `User` — `has_one :user_policy`
- [x] Model: `Push` — update `set_expire_limits` to check user policy
- [x] Controller: `UserPoliciesController` (edit/update)
- [x] API Controller: `Api::V1::UserPoliciesController` (show/update)
- [x] Views: User policy settings form with per-kind sections
- [x] Routes: `resource :user_policy` (HTML + JSON API)
- [x] Config: `enable_user_policies: false` setting + `PWP__ENABLE_USER_POLICIES` env var
- [x] Helper: `effective_default` in PushesHelper for form defaults
- [x] Concern: `SetPushAttributes` updated for user policy retrieval_step/deletable defaults
- [x] Navigation: "Push Defaults" link in account dropdown (conditionally shown)
- [x] Tests: Model tests, controller tests, push integration tests
- [x] Fixtures: `user_policies.yml`
- [x] All 4 push forms updated (_form, _url_form, _files_form, _qr_form)
- [x] Feature disabled by default (`enable_user_policies: false`)

### Files Created
- `db/migrate/20260224000001_create_user_policies.rb`
- `app/models/user_policy.rb`
- `app/controllers/user_policies_controller.rb`
- `app/controllers/api/v1/user_policies_controller.rb`
- `app/views/user_policies/edit.html.erb`
- `config/routes/user_policies.rb`
- `test/models/user_policy_test.rb`
- `test/models/push_user_policy_test.rb`
- `test/controllers/user_policies_controller_test.rb`
- `test/fixtures/user_policies.yml`

### Files Modified
- `app/models/user.rb` — added `has_one :user_policy`
- `app/models/push.rb` — added `user_policy_default`, `user_policy_kind_key` methods; updated `set_expire_limits`
- `app/controllers/concerns/set_push_attributes.rb` — added user policy fallback for API defaults
- `app/helpers/pushes_helper.rb` — added `effective_default` helper
- `app/views/pushes/_form.html.erb` — use `effective_default` for text push defaults
- `app/views/pushes/_url_form.html.erb` — use `effective_default` for URL push defaults
- `app/views/pushes/_files_form.html.erb` — use `effective_default` for file push defaults
- `app/views/pushes/_qr_form.html.erb` — use `effective_default` for QR push defaults
- `app/views/shared/_header.html.erb` — added "Push Defaults" dropdown link
- `config/settings.yml` — added `enable_user_policies: false`
- `config/routes.rb` — added `draw :user_policies`
- `config/routes/pwp_api.rb` — added API user_policy route

### Verification
- [x] Feature is disabled by default (`enable_user_policies: false`)
- [x] When disabled: no routes registered, no dropdown link shown, no model queries
- [x] Settings resolution chain: User Policy > Global Settings
- [x] Form defaults reflect user policy when enabled + user has policy
- [x] API endpoints gated behind feature flag

**PHASE COMPLETE.**

---

## Phase 2: Two-Factor Authentication (2FA)

### Goal
TOTP-based 2FA with authenticator apps + backup codes.

### Deliverables
- [x] Gem: `rotp ~> 6.3` added to Gemfile
- [x] Migration: Add `otp_secret_ciphertext`, `otp_required_for_login`, `consumed_timestep` to users; create `otp_backup_codes` table
- [x] Model: `OtpBackupCode` with BCrypt digest verification
- [x] Model: `User` — OTP methods (generate, verify, enable, disable, backup codes)
- [x] Controller: `Users::TwoFactorController` (setup, enable, disable, regenerate_backup_codes)
- [x] Controller: `Users::TwoFactorVerificationController` (OTP challenge on login)
- [x] Controller: `Users::SessionsController` — two-step login when 2FA enabled
- [x] Views: Setup page (QR code + manual key), OTP input form, backup codes display
- [x] Views: 2FA section in account settings (enable/disable with password confirmation)
- [x] Routes: `config/routes/two_factor.rb`
- [x] Config: `enable_two_factor: false` setting + `PWP__ENABLE_TWO_FACTOR` env var
- [x] Tests: 15 model tests, 9 controller tests, 6 verification tests (30 total)
- [x] Feature disabled by default (`enable_two_factor: false`)

### Files Created
- `db/migrate/20260224000002_add_two_factor_to_users.rb`
- `app/models/otp_backup_code.rb`
- `app/controllers/users/two_factor_controller.rb`
- `app/controllers/users/two_factor_verification_controller.rb`
- `app/views/users/two_factor/setup.html.erb`
- `app/views/users/two_factor/backup_codes.html.erb`
- `app/views/users/two_factor_verification/new.html.erb`
- `config/routes/two_factor.rb`
- `test/models/user_two_factor_test.rb`
- `test/controllers/two_factor_controller_test.rb`
- `test/controllers/two_factor_verification_controller_test.rb`
- `test/fixtures/otp_backup_codes.yml`

### Files Modified
- `Gemfile` — added `rotp ~> 6.3`
- `app/models/user.rb` — added 2FA methods, `has_many :otp_backup_codes`, `has_encrypted :otp_secret`
- `app/controllers/users/sessions_controller.rb` — two-step login flow for 2FA users
- `app/views/devise/registrations/edit.html.erb` — added 2FA section (enable/disable/regenerate)
- `config/settings.yml` + `config/defaults/settings.yml` — added `enable_two_factor: false`
- `config/routes.rb` — added `draw :two_factor`

### Verification
- [x] 681 runs, 3956 assertions, 0 failures, 0 errors
- [x] Feature disabled by default
- [x] Two-step login: password first, then OTP challenge
- [x] Backup codes work as OTP alternative
- [x] Password required to disable 2FA
- [x] OTP replay protection via consumed_timestep

**PHASE COMPLETE.**

---

## Phase 3: SSO Login (Google & Microsoft)

### Goal
OAuth2 login via Google and Microsoft.

### Deliverables
- [x] Gems: `omniauth-google-oauth2 ~> 1.2`, `omniauth-microsoft_graph ~> 2.0`, `omniauth-rails_csrf_protection ~> 1.0`
- [x] Migration: Add `provider`, `uid` to users (indexed unique together)
- [x] Model: `User` — `:omniauthable`, `from_omniauth`, `sso_user?`
- [x] Initializer: `config/initializers/omniauth.rb` with dynamic provider registration
- [x] Controller: `Users::OmniauthCallbacksController` — google_oauth2 and microsoft_graph callbacks
- [x] Views: SSO buttons partial on login/registration pages
- [x] Config: `sso.google.enabled: false`, `sso.microsoft.enabled: false`
- [x] Tests: Model + controller tests
- [x] Feature disabled by default

### Verification
- [x] 690 runs, 3981 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phase 4: Per-User Branding & White-Label

### Goal
Company logo on delivery pages, custom text, 100% white-label.

### Deliverables
- [x] Migration: Create `user_brandings` table
- [x] Model: `UserBranding` with Active Storage logo, validations
- [x] Controller: `UserBrandingsController` (edit/update)
- [x] Views: Branding settings form, delivery partials
- [x] Layouts: `bare.html.erb` + `naked.html.erb` render branding
- [x] Config: `enable_user_branding: false`
- [x] Tests: Model + controller tests
- [x] Feature disabled by default

### Verification
- [x] 705 runs, 4005 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phase 5: Request / Intake Forms

### Goal
Create links that let third parties submit text/files/URLs back to you.

### Deliverables
- [x] Migration: Create `requests` table + `request_id` on pushes
- [x] Model: `Request` with URL token, expiration, submission tracking
- [x] Model: `Push` — `belongs_to :request, optional: true`
- [x] Controller: `RequestsController` (CRUD, authenticated)
- [x] Controller: `RequestSubmissionsController` (public intake form)
- [x] Mailer: `RequestMailer` — notify requester on submission
- [x] Views: Request management + public intake form + thank you/expired pages
- [x] Routes: `resources :requests` + member POST on `:req` for submissions
- [x] Config: `enable_requests: false`
- [x] Navigation: "Requests" link in account dropdown
- [x] Tests: 11 model tests, 7 controller tests, 4 submission tests (22 total)
- [x] Feature disabled by default

### Verification
- [x] 727 runs, 4037 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phase 6: Teams Foundation

### Goal
Team collaboration with invitations and role-based access.

### Deliverables
- [x] Migration: Create `teams`, `memberships`, `team_invitations` tables + `team_id` on pushes
- [x] Model: `Team` with slug, owner, member helpers, auto-add-owner
- [x] Model: `Membership` with role enum (member/admin/owner), permissions
- [x] Model: `TeamInvitation` with token, expiration, accept logic
- [x] Model: `User` — `has_many :memberships/teams/owned_teams`
- [x] Model: `Push` — `belongs_to :team, optional: true`
- [x] Controller: `TeamsController` (CRUD + dashboard)
- [x] Controller: `MembershipsController` (role changes, remove/leave)
- [x] Controller: `TeamInvitationsController` (invite, revoke, token-based accept)
- [x] Mailer: `TeamMailer` (invitation_email, member_added)
- [x] Views: Team index, show (with members, invitations, pushes), create/edit forms
- [x] Routes: `config/routes/teams.rb` with nested memberships/invitations + public accept
- [x] Config: `enable_teams: false`
- [x] Navigation: "Teams" link in account dropdown
- [x] Tests: 16 model tests, 6 membership tests, 12 invitation tests, 11 controller tests, 5 membership controller tests, 7 invitation controller tests (56 total)
- [x] Feature disabled by default

### Verification
- [x] 783 runs, 4132 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phase 7: Team Policies & Configuration

### Goal
Team policies with forced defaults, hidden features, and global configuration.

### Deliverables
- [x] Migration: Add `policy` JSON column to teams
- [x] Model: `Team` — policy accessor methods (defaults, forced, hidden_features, limits)
- [x] Model: `Push` — settings resolution chain: Team Forced > Team Default > User Policy > Global Settings
- [x] Controller: `TeamPoliciesController` (edit/update, team admin only)
- [x] Views: Policy settings form with per-kind defaults, force-lock toggles, feature visibility, limits
- [x] Routes: Nested `resource :policy` under teams
- [x] Tests: 11 model tests, 5 push integration tests, 5 controller tests (21 total)

### Verification
- [x] 804 runs, 4158 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phase 8: Team 2FA Enforcement

### Goal
Team admins can require 2FA for all members.

### Deliverables
- [x] Migration: Add `require_two_factor` boolean to teams
- [x] Model: `Team` — `members_without_2fa` scope, compliance percentage
- [x] Controller: `TeamTwoFactorController` — compliance dashboard, toggle, remind
- [x] Concern: `TeamTwoFactorEnforcement` — redirects non-2FA users to setup
- [x] Mailer: `TeamMailer#two_factor_reminder`
- [x] Views: 2FA compliance dashboard with status indicators, enforcement toggle, reminder button
- [x] Routes: Nested under teams with remind action
- [x] Tests: 5 model tests, 7 controller tests, 4 enforcement tests (16 total)
- [x] Concern included in BaseController

### Verification
- [x] 820 runs, 4178 assertions, 0 failures, 0 errors

**PHASE COMPLETE.**

---

## Phases 1-8 Complete

All 16 Pro features have been implemented across 8 phases:
- **820 total tests**, **4178 assertions**, **0 failures**, **0 errors**
- All features gated behind `Settings.enable_xxx` / `PWP__ENABLE_XXX` env vars
- All features disabled by default — no impact on existing functionality
- Settings resolution chain: Team Forced > Team Default > User Policy > Global Settings

---

## Phase 9: GitHub Actions CI

### Goal
Automated test + lint pipeline on every push/PR.

### Deliverables
- [x] CI workflow: `.github/workflows/ci.yml`
- [x] `lint` job: RuboCop, ErbLint, Brakeman (Ruby 4.0.1)
- [x] `test-sqlite` job: Ruby 4.0.1, Node 20, yarn, SQLite
- [x] `test-postgres` job: PostgreSQL 16 service container, Ruby 4.0.1, Node 20
- [x] Caching: bundler-cache via setup-ruby, yarn cache via actions/cache
- [x] No PWP__ env vars set (test_helper strips them)

### Files Created
- `.github/workflows/ci.yml`

### Verification
- [x] YAML syntax valid
- [x] Three independent jobs: lint, test-sqlite, test-postgres
- [x] PostgreSQL health checks configured
- [x] No secrets or sensitive data in workflow

**PHASE COMPLETE.**

---

## Phase 10: Docker Compose for Local Dev

### Goal
Containerized dev environment alongside existing production Docker setup.

### Deliverables
- [x] Dockerfile: `containers/docker/Dockerfile.dev` (Ruby 4.0.1-slim, Node 20, yarn)
- [x] Compose: `docker-compose.dev.yml` (app, PostgreSQL 16, Redis 7, MailCatcher)
- [x] Script: `bin/docker-dev` (up, down, build, test, console, bash, logs, setup)
- [x] Named `pwpush-dev` to avoid conflicts with production compose
- [x] Bundle cache in named volume for fast rebuilds
- [x] DATABASE_URL for PostgreSQL config
- [x] MailCatcher for email testing (port 1080)
- [x] Script is executable

### Files Created
- `containers/docker/Dockerfile.dev`
- `docker-compose.dev.yml`
- `bin/docker-dev`

### Verification
- [x] Compose file uses named project `pwpush-dev`
- [x] Health checks on postgres and redis
- [x] Source mounted as volume (live reload)
- [x] bin/docker-dev is executable and has all subcommands

**PHASE COMPLETE.**

---

## Phase 11: Audit Dashboard + Push Notifications

### Goal
Two features: (A) centralized audit log dashboard, (B) email notifications for push lifecycle events.

### 11A: Audit Log Dashboard

- [x] Controller: `AuditDashboardController` with index action, filters (kind, IP, push_token)
- [x] View: `audit_dashboard/index.html.erb` with filter bar, paginated table, color-coded kind badges
- [x] Routes: `config/routes/audit_dashboard.rb` (`GET /audit`)
- [x] Config: `enable_audit_dashboard: false` / `PWP__ENABLE_AUDIT_DASHBOARD`
- [x] Navigation: "Audit Log" link in account dropdown
- [x] Tests: 5 controller tests

### 11B: Push Expiration Notifications

- [x] Migration: Add `notify_on_view`, `notify_on_expire`, `notify_on_expiring_soon` to users; `expiring_soon_notified_at` to pushes
- [x] Mailer: `PushMailer` with `push_viewed`, `push_expired`, `push_expiring_soon`
- [x] Views: 6 mailer templates (HTML + text)
- [x] Job: `PushNotificationJob` dispatches mailer based on event type
- [x] Job: `ExpiringPushesNotificationJob` finds pushes expiring within 1 day
- [x] Config: `enable_push_notifications: false` / `PWP__ENABLE_PUSH_NOTIFICATIONS`
- [x] Modified LogEvents concern to enqueue notifications on view/expire
- [x] Modified Devise registration edit view with notification preference checkboxes
- [x] Modified ApplicationController for Devise permitted params
- [x] Tests: 3 mailer tests, 4 job tests, 3 expiring job tests

### Verification
- [x] 835 runs, 4205 assertions, 0 failures, 0 errors
- [x] Both features disabled by default
- [x] Settings test passes (defaults/settings.yml synced)

**PHASE COMPLETE.**

---

## Phase 12: Webhook Notifications

### Goal
Users register webhook URLs to receive HTTP POST notifications for push lifecycle events.

### Deliverables

- [x] Migration: `webhooks` table (user_id, url, secret_ciphertext, events JSON, enabled, failure tracking) + `webhook_deliveries` table
- [x] Model: `Webhook` with Lockbox-encrypted secret, HMAC signing, event validation, auto-disable on max failures
- [x] Model: `WebhookDelivery` for delivery tracking
- [x] Concern: `WebhookDispatch` (class method on Push to dispatch matching webhooks)
- [x] Job: `WebhookDeliveryJob` with HTTP POST, HMAC signature headers, polynomial retry
- [x] Controller: `WebhooksController` (full CRUD, inherits BaseController)
- [x] Views: index (table with status badges), new/edit (form with event checkboxes), show (details + delivery history)
- [x] Routes: `config/routes/webhooks.rb`
- [x] Config: `enable_webhooks: false` / `PWP__ENABLE_WEBHOOKS`, `webhooks.max_per_user`, `webhooks.max_failures`, `webhooks.retry_attempts`
- [x] Modified: `user.rb` (has_many :webhooks), `log_events.rb` (dispatch on view/create/expire/failed_passphrase), `request_submissions_controller.rb` (dispatch on request.submitted), `push.rb` (include WebhookDispatch)
- [x] Navigation: "Webhooks" link in account dropdown (gated by feature flag)
- [x] Tests: 11 controller tests, 10 model tests, 3 job tests

### Webhook Events
- `push.created`, `push.viewed`, `push.expired`, `push.failed_passphrase`, `request.submitted`

### Files Created
- `db/migrate/20260224000010_create_webhooks.rb`
- `app/models/webhook.rb`
- `app/models/webhook_delivery.rb`
- `app/models/concerns/webhook_dispatch.rb`
- `app/jobs/webhook_delivery_job.rb`
- `app/controllers/webhooks_controller.rb`
- `app/views/webhooks/index.html.erb`
- `app/views/webhooks/_form.html.erb`
- `app/views/webhooks/new.html.erb`
- `app/views/webhooks/edit.html.erb`
- `app/views/webhooks/show.html.erb`
- `config/routes/webhooks.rb`
- `test/controllers/webhooks_controller_test.rb`
- `test/models/webhook_test.rb`
- `test/jobs/webhook_delivery_job_test.rb`
- `test/fixtures/webhooks.yml`
- `test/fixtures/webhook_deliveries.yml`

### Files Modified
- `app/models/user.rb` -- added `has_many :webhooks`
- `app/models/push.rb` -- added `include WebhookDispatch`
- `app/controllers/concerns/log_events.rb` -- dispatch webhooks on view, creation, expire, failed_passphrase
- `app/controllers/request_submissions_controller.rb` -- dispatch `request.submitted` webhook
- `config/routes.rb` -- added `draw :webhooks`
- `config/settings.yml` + `config/defaults/settings.yml` -- webhook feature flags and settings
- `app/views/shared/_header.html.erb` -- Webhooks dropdown link

### Verification
- [x] 859 runs, 4247 assertions, 0 failures, 0 errors
- [x] Feature disabled by default
- [x] Settings test passes (defaults/settings.yml synced)

**PHASE COMPLETE.**

---

## Phase 13: Broader API Coverage

### Goal
Extend JSON API to cover Teams, Requests, and UserBranding.

### 13A: Teams API

- [x] `Api::V1::TeamsController` -- index, show (by slug), create, update, destroy
- [x] `Api::V1::TeamMembersController` -- index, create (by email), destroy (respects removable_by?)
- [x] `Api::V1::TeamInvitationsController` -- index, create, destroy
- [x] Feature flag gated: `Settings.enable_teams`
- [x] Tests: 9 teams, 7 members, 6 invitations = 22 tests

### 13B: Requests + UserBranding API

- [x] `Api::V1::RequestsController` -- index, show, create, update, destroy (soft-expire)
- [x] `Api::V1::UserBrandingsController` -- show, update
- [x] Feature flag gated: `Settings.enable_requests`, `Settings.enable_user_branding`
- [x] Tests: 7 requests, 4 branding = 11 tests

### Files Created
- `app/controllers/api/v1/teams_controller.rb`
- `app/controllers/api/v1/team_members_controller.rb`
- `app/controllers/api/v1/team_invitations_controller.rb`
- `app/controllers/api/v1/requests_controller.rb`
- `app/controllers/api/v1/user_brandings_controller.rb`
- `test/controllers/api/v1/teams_controller_test.rb`
- `test/controllers/api/v1/team_members_controller_test.rb`
- `test/controllers/api/v1/team_invitations_controller_test.rb`
- `test/controllers/api/v1/requests_controller_test.rb`
- `test/controllers/api/v1/user_brandings_controller_test.rb`

### Files Modified
- `config/routes/pwp_api.rb` -- added teams (nested members + invitations), requests, user_branding routes

### Verification
- [x] 33 new API tests, all passing
- [x] All features gated behind existing feature flags

**PHASE COMPLETE.**

---

## Phase 14: IP Allowlisting + Geofencing

### Goal
Two access restriction features: IP allowlisting and country-based geofencing.

### 14A: IP Allowlisting

- [x] Migration: `allowed_ips` and `allowed_countries` columns on pushes
- [x] `ip_allowed?(request_ip)` on Push model -- parses comma-separated IPs/CIDRs, uses `IPAddr`
- [x] `AccessRestriction` concern with `check_ip_restriction` and `check_geo_restriction`
- [x] Included in `PushesController` (HTML) and `Api::V1::PushesController`
- [x] `allowed_ips` permitted in push params (both HTML and API)
- [x] Config: `enable_ip_allowlisting: false` / `PWP__ENABLE_IP_ALLOWLISTING`
- [x] Tests: 6 model tests, 3 controller tests

### 14B: Geofencing

- [x] `GeoipLookup` service -- MaxMind GeoLite2 database reader, returns ISO country code
- [x] `country_allowed?(request_ip)` on Push model -- parses country codes, calls GeoipLookup
- [x] `allowed_countries` permitted in push params
- [x] Config: `enable_geofencing: false` / `PWP__ENABLE_GEOFENCING`, `geofencing.database_path`
- [x] Gem: `maxminddb` added to Gemfile
- [x] Tests: 2 service tests, 4 model tests

### Files Created
- `db/migrate/20260224000011_add_access_restrictions_to_pushes.rb`
- `app/controllers/concerns/access_restriction.rb`
- `app/services/geoip_lookup.rb`
- `test/models/push_ip_restriction_test.rb`
- `test/controllers/pushes_ip_restriction_test.rb`
- `test/services/geoip_lookup_test.rb`
- `test/models/push_geo_restriction_test.rb`

### Files Modified
- `app/models/push.rb` -- added `ip_allowed?` and `country_allowed?` methods
- `app/controllers/pushes_controller.rb` -- include AccessRestriction, before_action, push_params
- `app/controllers/api/v1/pushes_controller.rb` -- include AccessRestriction, before_action, push_params
- `config/settings.yml` + `config/defaults/settings.yml` -- IP allowlisting and geofencing settings
- `Gemfile` -- added maxminddb gem

### Verification
- [x] 907 runs, 4336 assertions, 0 failures, 0 errors
- [x] Both features disabled by default
- [x] Settings test passes (defaults/settings.yml synced)
- [x] Graceful degradation when MaxMind DB not available

**PHASE COMPLETE.**

---

## Phase 15: CLI Tool

### Goal
Standalone Ruby CLI wrapping the PasswordPusher JSON API.

### Deliverables

- [x] Gemspec: `pwpush-cli.gemspec` (faraday, thor, tty-table)
- [x] Gemfile with test deps (minitest, webmock)
- [x] `Pwpush::Config` -- loads from `~/.pwpush.yml` or env vars (PWPUSH_SERVER_URL, PWPUSH_API_TOKEN, PWPUSH_EMAIL)
- [x] `Pwpush::Client` -- Faraday HTTP client wrapping all API endpoints (create, get, expire, list active/expired, version)
- [x] `Pwpush::CLI` -- Thor-based CLI with 8 commands: push, file, url, list, expire, get, version, config
- [x] Executable `bin/pwpush`
- [x] Tests: 10 client tests (WebMock), 3 config tests = 13 tests total
- [x] README with installation, config, and usage examples

### Commands
```
pwpush push TEXT              # Create text push
pwpush file PATH              # Create file push
pwpush url URL                # Create URL push
pwpush list [--expired]       # List pushes
pwpush expire URL_TOKEN       # Expire a push
pwpush get URL_TOKEN           # Retrieve a push
pwpush version                # CLI + server version
pwpush config                 # Interactive config setup
```

### Files Created
- `tools/cli/pwpush-cli.gemspec`
- `tools/cli/Gemfile`
- `tools/cli/bin/pwpush`
- `tools/cli/lib/pwpush.rb`
- `tools/cli/lib/pwpush/version.rb`
- `tools/cli/lib/pwpush/config.rb`
- `tools/cli/lib/pwpush/client.rb`
- `tools/cli/lib/pwpush/cli.rb`
- `tools/cli/test/test_helper.rb`
- `tools/cli/test/client_test.rb`
- `tools/cli/test/config_test.rb`
- `tools/cli/README.md`

### Verification
- [x] 13 CLI tests, 23 assertions, 0 failures, 0 errors
- [x] Main test suite: 907 runs, 4336 assertions, 0 failures, 0 errors
- [x] Standalone gem with no coupling to Rails app

**ALL 15 PHASES COMPLETE.**

---

## Post-Build: Polish & Hardening Improvements

### Goal
9 improvement tasks across 4 phases: jobs/config cleanup, API annotations/tests, lint/security fixes, and documentation.

### Phase A: Jobs, Config & Cleanup

- [x] **A1**: Wired `ExpiringPushesNotificationJob` into `config/recurring.yml` (every 6 hours, production + development)
- [x] **A2**: Created `WebhookDeliveryCleanupJob` with configurable retention (`delivery_retention_days: 30`), added to `config/recurring.yml` (daily at 2am), added tests
- [x] **A3**: Updated `.env.example` with all missing env vars from Phases 11-15

### Phase B: API Annotations & Tests

- [x] **B1**: Added Apipie annotations to 5 API controllers: `teams`, `team_members`, `team_invitations`, `requests`, `user_brandings`
- [x] **B2**: Created `test/integration/webhook_dispatch_test.rb` — 4 tests covering full webhook dispatch flow
- [x] **B3**: Created `test/controllers/api/v1/push_ip_restriction_api_test.rb` — 5 tests for IP allowlisting in API

### Phase C: Lint & Security

- [x] **C1**: RuboCop autocorrect — fixed 14 offenses (SpaceInsideHashLiteralBraces, UselessAssignment)
- [x] **C1**: ErbLint — fixed 11 missing `autocomplete` attributes across 5 view files
- [x] **C2**: Brakeman — fixed HIGH severity webhook URL regex (missing `\z` anchor), added 2 documented false positives to `brakeman.ignore`

### Phase D: Documentation

- [x] **D1**: Created `docs/geofencing-setup.md` — MaxMind GeoLite2 setup, Docker volumes, geoipupdate automation
- [x] **D2**: Created `docs/ruby-setup.md` — chruby + ruby-install setup for Ruby 4.0.1

### Files Created
- `app/jobs/webhook_delivery_cleanup_job.rb`
- `test/jobs/webhook_delivery_cleanup_job_test.rb`
- `test/integration/webhook_dispatch_test.rb`
- `test/controllers/api/v1/push_ip_restriction_api_test.rb`
- `docs/geofencing-setup.md`
- `docs/ruby-setup.md`

### Files Modified
- `config/recurring.yml` — added 2 recurring job entries
- `config/settings.yml` + `config/defaults/settings.yml` — added `delivery_retention_days: 30`
- `.env.example` — added missing env vars
- `app/controllers/api/v1/teams_controller.rb` — Apipie annotations
- `app/controllers/api/v1/team_members_controller.rb` — Apipie annotations
- `app/controllers/api/v1/team_invitations_controller.rb` — Apipie annotations
- `app/controllers/api/v1/requests_controller.rb` — Apipie annotations
- `app/controllers/api/v1/user_brandings_controller.rb` — Apipie annotations
- `app/models/concerns/webhook_dispatch.rb` — fixed JSON string parsing for events
- `app/models/webhook.rb` — fixed URL regex anchor
- `config/brakeman.ignore` — added 2 false positives, removed 1 obsolete entry
- 5 ERB views — added autocomplete attributes

### Verification
- [x] **919 runs, 4354 assertions, 0 failures, 0 errors** (up from 907 baseline)
- [x] RuboCop: 0 offenses
- [x] ErbLint: 0 offenses
- [x] Brakeman: 0 warnings (3 documented ignores)
- [x] `config/settings.yml` and `config/defaults/settings.yml` remain in sync

**POST-BUILD IMPROVEMENTS COMPLETE.**

---

## Post-Build Round 2: Comprehensive Hardening + API Expansion

### Goal
Address all audit findings: test coverage gaps, missing API endpoints, code quality fixes, documentation expansion.

### Test Coverage Improvements

- [x] **5 background job tests** — `expire_pushes_job`, `clean_up_pushes_job`, `cleanup_cache_job`, `purge_expired_pushes_job`, `purge_unattached_blobs_job` (13 tests)
- [x] **2 mailer tests** — `request_mailer` (4 tests), `team_mailer` (9 tests)
- [x] **4 mailer previews** — `push_mailer_preview`, `request_mailer_preview`, `team_mailer_preview`, `test_mailer_preview`
- [x] **Authorization failure tests** — 15 tests verifying cross-user resource isolation (pushes, webhooks, requests, teams)
- [x] **2 model tests** — `otp_backup_code` (8 tests), `webhook_delivery` (5 tests)
- [x] **3 API controller tests** — `pushes_controller` (12 tests), `version_controller` (3 tests), `user_policies_controller` (5 tests)

### New API Endpoints (3 controllers, 8 endpoints)

- [x] **Webhooks API** — `api/v1/webhooks_controller.rb` (index, show, create, update, destroy) with Apipie annotations + 11 tests
- [x] **Audit Logs API** — `api/v1/audit_logs_controller.rb` (index with filters: kind, ip, push_token) with Apipie annotations + 8 tests
- [x] **Team Policies API** — `api/v1/team_policies_controller.rb` (show, update) with Apipie annotations + 8 tests
- [x] Routes added to `config/routes/pwp_api.rb`

### Code Quality Fixes

- [x] **FIXME in push.rb** — replaced misleading FIXME with clarifying comment (only_path: true is intentional)
- [x] **N+1 in team_two_factor_controller** — materialized query to avoid duplicate SQL
- [x] **Hardcoded pagination extracted** — `.per(50)` and `page > 200` now use `Settings.api.per_page` / `Settings.api.max_page`
- [x] **i18n for base_controller.rb** — 3 hardcoded English strings wrapped with `_()` GetText
- [x] **Brakeman permit! fix** — team_policies API uses explicit key slicing instead of `permit!`
- [x] **RuboCop autocorrect** — 316 offenses fixed
- [x] **Removed duplicate test files** — 3 stale test/unit/ files removed (conflicted with test/jobs/)

### Documentation & Config

- [x] **.env.example expanded** — added API pagination vars + 14 brand icon env vars
- [x] **Settings extracted** — `api.per_page` and `api.max_page` added to settings.yml + defaults
- [x] **test_helper.rb** — added `last_email` helper method

### Files Created (19)
- `test/jobs/expire_pushes_job_test.rb`
- `test/jobs/clean_up_pushes_job_test.rb`
- `test/jobs/cleanup_cache_job_test.rb`
- `test/jobs/purge_expired_pushes_job_test.rb`
- `test/jobs/purge_unattached_blobs_job_test.rb`
- `test/mailers/request_mailer_test.rb`
- `test/mailers/team_mailer_test.rb`
- `test/mailers/previews/push_mailer_preview.rb`
- `test/mailers/previews/request_mailer_preview.rb`
- `test/mailers/previews/team_mailer_preview.rb`
- `test/integration/authorization_test.rb`
- `test/models/otp_backup_code_test.rb`
- `test/models/webhook_delivery_test.rb`
- `test/controllers/api/v1/pushes_controller_test.rb`
- `test/controllers/api/v1/version_controller_test.rb`
- `test/controllers/api/v1/user_policies_controller_test.rb`
- `app/controllers/api/v1/webhooks_controller.rb`
- `app/controllers/api/v1/audit_logs_controller.rb`
- `app/controllers/api/v1/team_policies_controller.rb`
- `test/controllers/api/v1/webhooks_controller_test.rb`
- `test/controllers/api/v1/audit_logs_controller_test.rb`
- `test/controllers/api/v1/team_policies_controller_test.rb`

### Verification
- [x] **1005 runs, 4563 assertions, 0 failures, 0 errors** (up from 919)
- [x] RuboCop: 0 offenses
- [x] Brakeman: 0 warnings (3 documented ignores)
- [x] `config/settings.yml` and `config/defaults/settings.yml` remain in sync

**ROUND 2 COMPLETE.**

---

## Phase 16: Admin Settings Panel + API

### Goal
Database-backed runtime settings overrides with admin HTML panel and REST API.

### Deliverables
- [x] `SettingOverride` model with typed value casting and `apply_all!` method
- [x] Migration: `setting_overrides` table (key, value, value_type)
- [x] Initializer to apply overrides on boot
- [x] Admin HTML panel with tabbed Bootstrap 5 UI (10 sections)
- [x] Admin Settings API: `GET/PATCH /api/v1/admin/settings.json`
- [x] Settings link in admin navigation
- [x] Apipie annotations on API endpoints

### Files Created
- `db/migrate/20260225000012_create_setting_overrides.rb`
- `app/models/setting_override.rb`
- `config/initializers/setting_overrides.rb`
- `app/controllers/admin/settings_controller.rb`
- `app/views/admin/settings/index.html.erb`
- `app/controllers/api/v1/admin/settings_controller.rb`
- `test/models/setting_override_test.rb`
- `test/controllers/admin/settings_controller_test.rb`
- `test/controllers/api/v1/admin/settings_controller_test.rb`

### Files Modified
- `config/routes/admin.rb` — settings routes
- `config/routes/pwp_api.rb` — admin API routes
- `app/views/admin/_navigation.html.erb` — Settings link

---

## Phase 17: User Account + 2FA + Notifications API

### Goal
Full REST API for user account management, 2FA lifecycle, and notification preferences.

### Deliverables
- [x] Account API: register, show, update, change password, delete, regenerate token
- [x] 2FA API: setup, enable, disable, regenerate backup codes
- [x] Notifications API: show/update preferences
- [x] All endpoints with Apipie annotations
- [x] Registration respects `enable_logins` and `disable_signups` flags

### Files Created
- `app/controllers/api/v1/accounts_controller.rb`
- `app/controllers/api/v1/two_factor_controller.rb`
- `app/controllers/api/v1/notification_preferences_controller.rb`
- `test/controllers/api/v1/accounts_controller_test.rb`
- `test/controllers/api/v1/two_factor_controller_test.rb`
- `test/controllers/api/v1/notification_preferences_controller_test.rb`

### Files Modified
- `config/routes/pwp_api.rb` — account/2FA/notification routes

---

## Phase 18: Team Management API Gaps

### Goal
Fill remaining team API gaps: member role updates, team 2FA enforcement, invitation acceptance.

### Deliverables
- [x] Team member role update: `PATCH /api/v1/teams/:slug/members/:id.json`
- [x] Team 2FA enforcement API: show compliance, toggle requirement, send reminders
- [x] Invitation accept API: `POST /api/v1/teams/invitations/:token/accept.json`
- [x] Owner role protection (immutable)

### Files Created
- `app/controllers/api/v1/team_two_factor_controller.rb`
- `test/controllers/api/v1/team_two_factor_controller_test.rb`

### Files Modified
- `app/controllers/api/v1/team_members_controller.rb` — added `update` action
- `app/controllers/api/v1/team_invitations_controller.rb` — added `accept` action
- `config/routes/pwp_api.rb` — team 2FA + invitation accept routes
- `test/controllers/api/v1/team_members_controller_test.rb` — role update tests
- `test/controllers/api/v1/team_invitations_controller_test.rb` — accept tests

---

## Phase 19: Swagger UI

### Goal
Interactive API documentation via Swagger UI served at `/api-docs`.

### Deliverables
- [x] Swagger UI page loading from CDN (no new gem)
- [x] Controller serving swagger.json from Apipie export
- [x] Rake task `swagger:generate` wrapping Apipie's static export
- [x] Routes: `/api-docs` and `/api-docs/swagger.json`

### Files Created
- `app/controllers/api_docs_controller.rb`
- `app/views/api_docs/index.html.erb`
- `lib/tasks/swagger.rake`
- `test/controllers/api_docs_controller_test.rb`

### Files Modified
- `config/routes.rb` — api-docs routes

---

## Verification (Phase 16-19)
- [x] **1074 runs, 4702 assertions, 0 failures, 0 errors** (up from 1005)
- [x] RuboCop: 0 offenses (456 files)
- [x] Brakeman: 0 warnings (3 documented ignores)
- [x] `config/settings.yml` and `config/defaults/settings.yml` remain in sync

**PHASE 16-19 COMPLETE — awaiting approval to proceed.**
