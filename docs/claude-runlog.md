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

### Remaining
- [ ] Commit
- [ ] Deploy to production
- [ ] Run migration on production

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
