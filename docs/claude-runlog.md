# Claude Execution Runlog — PasswordPusher Pro Features

## 2026-03-13: Security Audit — 10 Vulnerability Fixes

### Goal
Fix 10 security vulnerabilities identified during code audit (all except #8 SSO account linking).

### Fixes Applied

1. **#1 CRITICAL — Multipart blob ownership** (`app/controllers/active_storage/multipart_uploads_controller.rb`)
   - Added session-based blob ownership tracking
   - `verify_blob_ownership` before_action on part_url/complete/abort
   - Returns 403 if blob key not in session[:owned_blob_keys]

2. **#2 CRITICAL — Lockbox default key** (`config/initializers/lockbox.rb`)
   - Raises error in production if PWPUSH_MASTER_KEY not set
   - Default key retained only for development/test

3. **#3 CRITICAL — IDOR on push edit/update/audit/delete_file** (`app/controllers/pushes_controller.rb`)
   - Added `@push.user_id.nil? ||` check in 4 ownership verification blocks
   - Prevents anonymous push manipulation when user_id is NULL

4. **#4 HIGH — Passphrase brute-force** (`config/initializers/rack_attack.rb`)
   - Throttle: 5 attempts per 30s per IP on `/p/*/access`
   - Throttle: 10 attempts per minute per push URL token

5. **#5 HIGH — file_encryption_key leak** (`app/models/push.rb`)
   - Removed `file_encryption_key` from `to_json` API output

6. **#6 HIGH — Plaintext API tokens** (migration + 4 files)
   - Migration: `authentication_token_digest` column with unique index
   - Data migration: hashes existing plaintext tokens
   - Lookup: `Pwpush::TokenAuthentication.find_by_token` uses SHA-256 digest with plaintext fallback
   - Regeneration: returns plaintext once, stores digest
   - Token page: shows token via @display_token (from flash or stored)

7. **#7 HIGH — URL token entropy** (`app/models/push.rb`)
   - Changed from `SecureRandom.urlsafe_base64(rand(8..14))` to `SecureRandom.urlsafe_base64(16)`
   - Fixed at 16 bytes = 128 bits of entropy

8. **#9 MEDIUM — CSP allows HTTP** (`config/initializers/content_security_policy.rb`)
   - Removed `:http` and `:ws` from all directives
   - Only `:https` and `:wss` allowed

9. **#10 MEDIUM — Parameter filter gaps** (`config/initializers/filter_parameter_logging.rb`)
   - Added: authentication_token, authentication_token_digest, file_encryption_key, otp_secret, passphrase

10. **#11 MEDIUM — Insecure cookies** (`config/initializers/session_store.rb`)
    - Force secure cookies when `Rails.env.production?` (in addition to Settings.secure_cookies)

### Test Results
- 1124 runs, 4795 assertions, 0 failures, 7 errors (pre-existing admin route errors)

### Files Changed
- `config/initializers/lockbox.rb`
- `config/initializers/content_security_policy.rb`
- `config/initializers/filter_parameter_logging.rb`
- `config/initializers/session_store.rb`
- `config/initializers/rack_attack.rb`
- `app/models/push.rb`
- `app/controllers/pushes_controller.rb`
- `app/controllers/active_storage/multipart_uploads_controller.rb`
- `app/models/concerns/pwpush/token_authentication.rb`
- `app/controllers/api/base_controller.rb`
- `app/controllers/api/v1/accounts_controller.rb`
- `app/controllers/users/registrations_controller.rb`
- `app/views/devise/registrations/token.html.erb`
- `db/migrate/20260313000001_add_authentication_token_digest_to_users.rb`

### Status: DEPLOYED

---

## 2026-03-13: Security Fix #8 — SSO Account Linking Verification

### Goal
Require password verification before linking an SSO identity to an existing local account.

### Problem
`User.from_omniauth` auto-linked SSO to existing accounts by email match without verification,
allowing account takeover if an attacker controlled an OAuth account claiming the victim's email.

### Fix
- `User.from_omniauth` now returns `OmniauthResult` struct with status `:found`, `:conflict`, or `:created`
- On `:conflict`, controller stores auth data in session and redirects to `/users/sso/link`
- User must enter their existing password to verify account ownership
- Only after correct password is the SSO identity linked via `User#link_omniauth!`

### Files Changed
- `app/models/user.rb` — OmniauthResult struct, conflict detection, link_omniauth! method
- `app/controllers/users/omniauth_callbacks_controller.rb` — link_account/confirm_link actions
- `app/views/users/omniauth_callbacks/link_account.html.erb` — password verification form
- `config/routes/users.rb` — GET/POST `/users/sso/link`
- `test/models/user_omniauth_test.rb` — updated for OmniauthResult API
- `test/controllers/omniauth_callbacks_controller_test.rb` — conflict/link tests

### Test Results
- 1129 runs, 4819 assertions, 0 failures (5 new tests added)

### Status: DEPLOYED

---

## 2026-03-12: Phase 31 — Backblaze B2 Encrypted File Storage

### Goal
Support large file uploads (1.57 GB+) with client-side AES-256-GCM encryption, stored in Backblaze B2.

### Steps

1. **Research** — Read storage.yml, push.rb, multi_upload_controller.js, settings.yml, defiant B2 setup, nginx configs
   - Result: PWPush already has B2 in storage.yml, direct upload enabled, no file size limits, Lockbox used for text fields

2. **Create B2 Bucket** — `pwpush-files` with SSE-B2 encryption, scoped app key, CORS rules
   - Bucket ID: `8e278110b3eae62a9ec8011c`
   - App Key ID: `004e7103a6ae81c0000000002`
   - CORS: pwpush.aspendora.com + localhost:5100

3. **Migration** — `20260312000001_add_file_encryption_to_pushes.rb` adds `file_encryption_key_ciphertext`

4. **Push Model** — Added `has_encrypted :file_encryption_key`, `files_encrypted?`, expire clears key

5. **Settings** — Added `files.enable_encryption` flag (default true), updated storage provider docs

6. **Storage Config** — Added `force_path_style: true` for B2 in storage.yml

7. **Controllers** — Permitted `file_encryption_key` param in pushes + API controllers

8. **JSON API** — Added `files_encrypted` and `file_encryption_key` to JSON responses

9. **Encrypted Upload JS** — Created `encrypted_upload_controller.js`:
   - Intercepts form submission
   - Generates AES-256-GCM key via Web Crypto API
   - Encrypts files in 5 MB chunks with per-chunk IV
   - Uploads via Active Storage DirectUpload
   - Stores key in hidden form field

10. **Encrypted Download JS** — Created `encrypted_download_controller.js`:
    - Fetches encrypted file from B2 presigned URL
    - Decrypts client-side (chunked)
    - Triggers browser download with original filename

11. **View Updates** — Updated _files_form.html.erb, _form.html.erb, show.html.erb:
    - Conditional direct_upload: true (off when encryption enabled)
    - Encrypted download links for encrypted pushes
    - "End-to-end encrypted" badge with shield-lock icon

12. **Tests** — Updated 4 JSON retrieval tests to include `files_encrypted` field
    - 1124 tests, 4807 assertions, 0 failures, 0 errors

13. **Documentation** — Created `docs/b2-encrypted-storage.md` with architecture, format spec, deploy steps

### Remaining
- [x] Production deployment (deployed, migration ran, site confirmed HTTP 200)

---

## 2026-03-12: Upstream Cherry-Picks (Safe Commits Only)

### Goal
Integrate safe upstream PasswordPusher changes (dependency bumps, doc fixes) without touching any destructive v2.0.0 changes.

### Steps

1. **Alpine fix** — Cherry-picked `06be0497` (libffi-dev dependency for Docker)
2. **GitHub Actions bumps** (7 commits) — Cherry-picked with one conflict resolution in dependabot-automerge.yml (added checkout step):
   - actions/checkout v4→v6
   - actions/upload-artifact v6→v7
   - docker/login-action v3→v4, metadata-action v5→v6, setup-buildx-action v3→v4, build-push-action v6→v7, setup-qemu-action v3→v4
3. **JS dependency bumps** (2 commits) — minimatch 10.2.2→10.2.4, immutable 5.1.4→5.1.5
4. **Doc link fix** — Manually applied e957103c (login setup link → docs.pwpush.com)
5. **Ruby gem updates** — SKIPPED. `bundle update` fails due to apipie-rails git source conflict with mission_control-jobs. Needs separate investigation.
6. **Tests** — 1124 runs, 4807 assertions, 0 failures, 0 errors

### Remaining
- [ ] Push to GitHub
- [ ] Rebuild and redeploy production
- [ ] Investigate bundle update conflict (apipie-rails git source + mission_control-jobs)

---

## 2026-02-27: Phase 30 — Entra ID Avatars, Dark Mode Toggle, Dark Mode Logos

### Goal
Three enhancements: SSO avatars, manual dark mode toggle, dark mode branding logos.

### Steps
1. **Migration** — `20260227000015_add_avatar_url_to_users.rb` adds `avatar_url` string column
2. **User model** — `from_omniauth` now extracts `auth.info.image` and stores/updates `avatar_url`

---

## 2026-03-13: Phases 32-40 — Feature Batch Build

### Goal
Build 9 feature phases in one session: Push Templates, CSP Integration, Reporting, Expiration Notifications, Teams Bot, Custom URLs, Bulk API, ClamAV, Redis.

### Steps
1. **Phase 32: Push Templates** — PushTemplate model (enum kind, team scoping), HTML + API CRUD, template selector partial + Stimulus controller, 35 tests
2. **Phase 33: CSP Client Discovery + Multi-Tenant SSO + Onboarding** — CspTenant model, CippClient OAuth service, ClientMailer onboarding email, OmniAuth multi-tenant common endpoint, callback tenant validation, admin CRUD + API, 27 tests
3. **Phase 34: Usage & Compliance Reporting Dashboard** — DailyGroupable concern, Reports controller with Chart.js dashboard, API, 9 tests
4. **Phase 35: Scheduled Push Expiration Notifications** — Added configurable `push_notifications.expiring_soon_days` setting
5. **Phase 36: Microsoft Teams Bot** — TeamsNotifier service (MessageCard), TeamsNotificationJob, WebhookDispatch integration, 4 tests
6. **Phase 37: Custom Short URLs** — custom_url_token column + migration, Push model validation + find_by_token, controller updates
7. **Phase 38: Bulk Push API + Webhook Read Receipts** — bulk_create action (max 50), read_at migration, mark_delivery_read API
8. **Phase 39: ClamAV File Scanning** — ClamavScanner service (clamd INSTREAM protocol), FileScanJob, after_commit hook
9. **Phase 40: Redis for Rack::Attack** — redis gem, Settings.redis.url, RedisCacheStore with FileStore fallback

### Bug Fixes
- Teams test fixtures: Changed `pushes(:one)` to `pushes(:test_push)` (correct fixture name)
- Added `assert_nothing_raised` to silence "missing assertions" warnings in job tests

### Settings Added
- `enable_push_templates`, `enable_csp_integration`, `enable_reports`, `enable_teams_notifications`, `enable_custom_urls`, `enable_clamav`
- `push_templates.max_per_user`, `push_notifications.expiring_soon_days`, `teams.webhook_url`, `clamav.host/port`, `redis.url`

### Verification
- **1204 runs, 4998 assertions, 0 failures, 0 errors**
- Settings files byte-identical (config/settings.yml == config/defaults/settings.yml)
- All migrations applied

---

## 2026-06-01 — Fix: Microsoft SSO login loops back to "not logged in"

**Goal:** Diagnose why a Windows client could reach pwpush.aspendora.com (DNS/ping fine) but Microsoft SSO login kept bouncing back to a logged-out state.

**Diagnosis:** Root cause is the session cookie `same_site: :strict` in `config/initializers/session_store.rb` (active in production). With `SameSite=Strict`, the browser will not attach the `_PasswordPusher_session` cookie on cross-site top-level navigations — i.e. the redirect chain returning from `login.microsoftonline.com` and the subsequent redirect to the dashboard. The OAuth callback signs the user in and sets the cookie, but the very next (cross-site) request omits it, so the app sees no session → login page → loop. Password logins (fully same-site) are unaffected, which is why it looked SSO/machine-specific. Not a networking/DNS issue.

**What I did:** Changed the production session cookie from `same_site: :strict` to `same_site: :lax`. Lax still sends the cookie on top-level GET navigations (OAuth redirects) while retaining CSRF protection against cross-site POST/subresource requests.

**Files changed:** `config/initializers/session_store.rb`

**Commands run:** `ssh` to prod (port 22 timed out / filtered from current network — could not pull live logs or deploy remotely).

**Result:** Code fix committed locally on `master`. Requires deploy (rebuild) to take effect — initializer change needs app restart.

**Next required steps:**
1. Push to `origin/master`.
2. On server: `cd /opt/docker/pwpush && git pull && docker build -f containers/docker/Dockerfile -t pwpush:latest . && cd /opt/docker && docker compose up -d pwpush`
3. Re-test Microsoft SSO from the Windows client.
4. Sanity check: confirm normal password login still works (should be unaffected).

**DEPLOYED (2026-06-01):** Discovered prod actually runs on Vultr/Proxmox VM 301 `docker-apps` (reach via Tailscale `ssh docker-apps`), behind NPM, deploy dir `/opt/services/pwpush` (image-only, no source on box). Live logs confirmed the failure: `omniauth (microsoft_graph) csrf_detected`. Deployed the `:lax` fix as a derived image layer (rollback tag `pwpush:pre-samesite-fix`). Verified live: `config.session_options` → `same_site: :lax`, container healthy. Still TODO: push commit c8b71d58 to origin/master.

---

## 2026-06-09 — Upstream security backport (3 fixes)

**Goal:** Audit upstream PasswordPusher (we forked at `e26cdc6c`, 2026-02-23; upstream now v2.7.2) for security changes we lack and backport the relevant ones. Upstream is 348 commits ahead (243 dep bumps, 9 i18n, ~96 real). Focused on security.

**Findings & actions:**
1. **GH #4381 — file-upload auth enforcement (High):** Our v1 API `create` only authenticated when `!allow_anonymous`. The base controller's `require_api_authentication` already gates `/f.json` and `/r.json` create, but **not `/p.json` create** — so an anonymous client could create a *file* push via `/p.json` with a `files` key (or `kind=file`) and upload attachments without auth. Backported upstream's `requires_authentication_for_create?` helper (adapted: no APIv2 in our fork; kept `enable_logins` guard so no-login deployments don't call `authenticate_user!`). File: `app/controllers/api/v1/pushes_controller.rb`. New test: `test/integration/file_push/file_push_api_auth_test.rb` (4 tests, 13 assertions).
2. **GH #4289 — trusted proxies (Med-High):** Prod/dev `trusted_proxies` were missing `172.16/12` (**Docker bridge** — our prod runs in Docker behind NPM), `127.0.0.0/8`, `169.254/16`, `100.64/10`. This affects accuracy of our IP-allowlist + geofence features. Expanded both `config/environments/production.rb` and `development.rb` to the full RFC 1918 / loopback / link-local / RFC 6598 set.
3. **GH #4382 — CSP `base_uri :self` (Med):** Added `policy.base_uri :self` to `config/initializers/content_security_policy.rb` (blocks `<base>` tag injection). Skipped `strict_dynamic` — needs separate JS-loading testing.

**Not backported (already covered / N/A):** upstream's own 2FA + `require_mfa` (we built our own 2FA + team 2FA enforcement); Custom-CSS HTML escaping (we don't have in-app Custom CSS); compose-only-443 (prod fronts with NPM).

**Also fixed:** stale `session_store_test.rb` assertion (`:strict` → `:lax`) left over from the SSO SameSite fix (commit c8b71d58) — it had been failing since that change.

**Verification:** Full suite green — **1208 runs, 5010 assertions, 0 failures, 0 errors**. (Ruby 4.0.1 via chruby.)

**Next:** commit + push to origin/master (carries c8b71d58 too).

---

## 2026-06-09 — Phase 41: Upstream UX backports (cont. from security backport)

**Goal:** Backport non-security "may need" upstream features. User approved all; chose to **skip importmap migration** (#4285, keep esbuild) and **defer Ruby 4.0.3/Puma 8** (#4403, bundle-update blocked).

**Done (4 features):** dark error pages (8d3773ba), auto re-blur 20s (#4383), Show/Hide Additional Options collapse across 4 forms (#4348), copyable share message on preview (#4474). New files: `app/helpers/share_message_helper.rb`, `app/views/shared/_additional_options.html.erb`, `app/views/shared/_share_message.html.erb`, `test/helpers/share_message_helper_test.rb`. Added `reveal_additional_options` system-test helper; patched 5 system tests (push_cookies, file_push_cookies, url_cookies, push_creation_workflows, file_push_editing) to expand the collapse.

**Verification:** full unit/integration **1211 runs, 0 failures** (7 errors = pre-existing admin route-reload order pollution; admin test passes 7/7 alone). System tests green in isolation. All residual failures proven pre-existing via `git stash` baseline run.

**Next:** Phase 42 (user-timezone #4274 — needs local_time gem) and Phase 43 (APIv2 #4371). Awaiting checkpoint per CLAUDE.md §11.

---

## 2026-06-09 — Phase 42: User-timezone display (#4274)

Added `local_time` gem (3.0.3, clean single-gem bundle install). Ported `local_time_locales.js` + `application.js` hooks (local-time npm was already imported). Converted all 16 date renderings to `local_time`/`local_date` (pushes index/audit, teams ×2, admin users ×4, 8 audit_log partials with `.html_safe` + `h()` XSS guard). Full suite 1211 runs, 0 failures (8 errors = pre-existing pollution, pass in isolation). Next: Phase 43 APIv2.

---

## 2026-06-09 — Phase 43: APIv2 (#4371)

Added `/api/v2` surface: `Api::V2::PushesController < Api::V1::PushesController` (overrides push_params to use the `push` namespace; inherits all v1 extensions + the #4381 security fix), `Api::V2::VersionController` (api_version "2.0"), v2 routes (version + pushes except new/index/edit/update + preview/audit/active/expired), and base_controller v2 auth gating. Tests: api_v2_version_test (2) + api_v2_pushes_test (19), adapted (dropped /help/api page; enable_logins in setup). Skipped the upstream static help page + footer link (we have /api + /api-docs; footer is redesigned). Full suite: **1232 runs, 0 failures, 0 errors** (clean). Phases 41-43 complete.
