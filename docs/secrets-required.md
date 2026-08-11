# Required Secrets — PasswordPusher

Secret **values** live only in `~/.secrets/.env` on the operator's workstation and in
`/opt/services/pwpush/.env` on the deployment host. Nothing in this repo contains a real value.

To load them locally: `set -a && . ~/.secrets/.env && set +a`

## Core application

| Env var | Purpose | Where to get it |
|---------|---------|-----------------|
| `PWPUSH_MASTER_KEY` | Lockbox master key — encrypts push payloads, notes, passphrases and dispatch destinations | Generated once at setup. **Losing this makes every stored secret unreadable.** |
| `SECRET_KEY_BASE` | Rails session/cookie signing | `bin/rails secret` |
| `DATABASE_URL` | PostgreSQL connection string | Composed from `PWPUSH_DB_PASSWORD` |
| `PWPUSH_DB_PASSWORD` | Password for the `pwpush` Postgres role | Set at DB provisioning |

## Email — SMTP2GO

| Env var | Purpose | Where to get it |
|---------|---------|-----------------|
| `PWP__MAIL__DELIVERY_METHOD` | `smtp2go_api` (HTTP API) or `smtp` (fallback) | Config choice, not a secret |
| `PWP__MAIL__SMTP2GO_API_KEY` | SMTP2GO API key with the `/email/send` scope | SMTP2GO dashboard → Sending → API Keys. Stored as `SMTP2GO_API_KEY` in `~/.secrets/.env`. |
| `PWP__MAIL__MAILER_SENDER` | From address, e.g. `PasswordPusher <noreply@aspendora.com>` | Must be a **verified sender** in SMTP2GO or every send fails |
| `PWP__MAIL__SMTP_USER_NAME` / `PWP__MAIL__SMTP_PASSWORD` | Only used when `delivery_method: smtp` | SMTP2GO dashboard → SMTP Users |

Rotation: create a second API key in SMTP2GO, swap it into both env files, redeploy, then delete
the old key.

## SMS — Clerk Chat

| Env var | Purpose | Where to get it |
|---------|---------|-----------------|
| `PWP__CLERK_CHAT__API_KEY` | Clerk Chat API key (sent as the `apiKey` header) | Clerk Chat dashboard. Stored as `CLERKCHAT_API_KEY` in `~/.secrets/.env`. |
| `PWP__CLERK_CHAT__SENDER` | Business number messages come from, E.164 | Clerk Chat dashboard. Aspendora: `+12819414028`. |

## SSO — Microsoft Entra ID

| Env var | Purpose |
|---------|---------|
| `PWPUSH_SSO_MICROSOFT_CLIENT_ID` | App registration client ID |
| `PWPUSH_SSO_MICROSOFT_CLIENT_SECRET` | App registration client secret |
| `PWP__SSO__MICROSOFT__TENANT_ID` | Aspendora tenant ID (not secret) |

## File storage — Backblaze B2

| Env var | Purpose |
|---------|---------|
| `PWP__FILES__S3__ACCESS_KEY_ID` | B2 application key ID |
| `PWP__FILES__S3__SECRET_ACCESS_KEY` | B2 application key |
| `PWP__FILES__S3__ENDPOINT` / `__REGION` / `__BUCKET` | Bucket coordinates (not secret) |

## CSP tenant discovery — CIPP

| Env var | Purpose |
|---------|---------|
| `CIPP_CLIENT_ID` / `CIPP_CLIENT_SECRET` / `CIPP_TENANT_ID` / `CIPP_API_URL` | CIPP API credentials for tenant sync |

## API access (clients calling pwpush)

| Env var | Purpose |
|---------|---------|
| `PWPUSH_USER_EMAIL` | Service account email for API calls |
| `PWPUSH_USER_TOKEN` | That account's API token (Account settings → Authentication token) |

Used by n8n automations and by the `pwpush-mcp` server (`~/code/pwpush-mcp/`).
Rotate with `POST /api/v1/account/token`, then update every consumer.

## If a secret is found in the repo

1. Remove/redact it immediately and rotate it at the provider.
2. Add it here **without the value**.
3. Note the remediation in `docs/claude-runlog.md`.
