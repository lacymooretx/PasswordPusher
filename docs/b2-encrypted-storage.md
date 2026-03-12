# Backblaze B2 Encrypted File Storage

## Overview

File pushes use client-side AES-256-GCM encryption. Files are encrypted in the
browser before being uploaded to Backblaze B2 via Active Storage direct upload.
The encryption key for each push is stored in the database, encrypted by Lockbox.

Neither B2 nor the Rails server ever sees unencrypted file contents.

## Architecture

```
Browser                     Rails Server              Backblaze B2
  |                              |                         |
  |-- Generate AES-256 key ----->|                         |
  |-- Encrypt file (5MB chunks)  |                         |
  |-- Request presigned URL ---->|                         |
  |<-- Presigned URL ------------|                         |
  |-- Upload encrypted file -----|------------------------>|
  |-- Submit form + key -------->|                         |
  |                              |-- Store key (Lockbox) ->|
  |                              |                         |
  |===== DOWNLOAD FLOW ========= |                         |
  |-- View push ----------------->|                         |
  |<-- Page + decryption key ----|                         |
  |-- Fetch encrypted file ------|------------------------>|
  |<-- Encrypted file ---------- |<------------------------|
  |-- Decrypt in browser         |                         |
  |-- Save decrypted file        |                         |
```

## Encrypted File Format

Binary format with 29-byte header:

| Offset | Size   | Field            | Description                      |
|--------|--------|------------------|----------------------------------|
| 0      | 4      | Magic            | `PWPE` (0x50575045)              |
| 4      | 1      | Version          | `0x01`                           |
| 5      | 4      | Chunk size       | uint32 BE (default: 5,242,880)   |
| 9      | 8      | Original size    | float64 BE (original file bytes) |
| 17     | 12     | Base IV          | Random nonce                     |

After the header, each chunk is AES-256-GCM ciphertext + 16-byte auth tag.
Per-chunk IV = base_iv XOR chunk_index (last 4 bytes).

## Production Setup

### Required Environment Variables

Add to `/opt/docker/.env`:

```bash
# Backblaze B2 Storage
PWP__FILES__STORAGE=backblaze_b2
PWP__FILES__S3__ENDPOINT=https://s3.us-west-004.backblazeb2.com
PWP__FILES__S3__ACCESS_KEY_ID=<from ~/.secrets/.env: PWPUSH_B2_ACCESS_KEY>
PWP__FILES__S3__SECRET_ACCESS_KEY=<from ~/.secrets/.env: PWPUSH_B2_SECRET_KEY>
PWP__FILES__S3__REGION=us-west-004
PWP__FILES__S3__BUCKET=pwpush-files

# File Encryption (enabled by default, set to false to disable)
# PWP__FILES__ENABLE_ENCRYPTION=true
```

### Nginx Configuration

Direct uploads bypass nginx (browser → B2 directly), but the form submission
and presigned URL requests still go through nginx. Add to the nginx server block:

```nginx
# Allow large form bodies (metadata for file pushes)
client_max_body_size 100m;

# Increase proxy timeouts for presigned URL generation
proxy_read_timeout 300;
proxy_connect_timeout 300;
proxy_send_timeout 300;
```

### B2 Bucket Details

- **Bucket**: `pwpush-files`
- **Bucket ID**: `8e278110b3eae62a9ec8011c`
- **Region**: `us-west-004`
- **Endpoint**: `https://s3.us-west-004.backblazeb2.com`
- **Encryption**: SSE-B2 (AES256) at rest + client-side AES-256-GCM
- **CORS**: Allows `https://pwpush.aspendora.com` and `http://localhost:5100`
- **Access**: Scoped app key (read/write/delete files, list buckets)

### Deploy Steps

1. Add env vars to `/opt/docker/.env`
2. Update nginx config with `client_max_body_size`
3. Rebuild and restart:
   ```bash
   cd /opt/docker/pwpush && git pull
   docker build -f containers/docker/Dockerfile -t pwpush:latest .
   cd /opt/docker && docker compose up -d pwpush
   ```
4. Run migration:
   ```bash
   docker exec pwpush bin/rails db:migrate
   ```
5. Test by uploading a file push

## Feature Flag

- `Settings.files.enable_encryption` / `PWP__FILES__ENABLE_ENCRYPTION`
- Default: `true`
- When disabled, files upload without encryption (original behavior)
- Existing unencrypted pushes continue to work regardless of this setting
- The `files_encrypted?` method on Push determines per-push behavior

## Security Model

- **At rest (B2)**: Double encrypted — SSE-B2 (B2-managed keys) + AES-256-GCM (app-managed keys)
- **In transit**: HTTPS (browser → B2 direct upload, browser → Rails)
- **Key storage**: Per-push AES key encrypted by Lockbox master key in PostgreSQL
- **Key lifecycle**: Key is deleted when the push expires (along with files)
- **Access control**: Same as push — URL token, passphrase, IP allowlist, view limits, expiry
