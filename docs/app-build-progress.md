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

## All Phases Complete

All 16 Pro features have been implemented across 8 phases:
- **820 total tests**, **4178 assertions**, **0 failures**, **0 errors**
- All features gated behind `Settings.enable_xxx` / `PWP__ENABLE_XXX` env vars
- All features disabled by default — no impact on existing functionality
- Settings resolution chain: Team Forced > Team Default > User Policy > Global Settings
