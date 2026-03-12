# Claude Execution Runlog — PasswordPusher Pro Features

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
- [ ] Production deployment (nginx config, env vars, rebuild Docker image)

---

## 2026-02-27: Phase 30 — Entra ID Avatars, Dark Mode Toggle, Dark Mode Logos

### Goal
Three enhancements: SSO avatars, manual dark mode toggle, dark mode branding logos.

### Steps
1. **Migration** — `20260227000015_add_avatar_url_to_users.rb` adds `avatar_url` string column
2. **User model** — `from_omniauth` now extracts `auth.info.image` and stores/updates `avatar_url`
