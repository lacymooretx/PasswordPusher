# Secret Link Dispatch (Email + SMS)

How a push's secret link gets to a human, and how delivery is recorded.

Added 2026-08-11 (Phases 44–48). Full external API reference lives in
`~/code/apis/pwpush-api/dispatch.md`; this doc covers the implementation.

## What changed

| Area | Before | After |
|------|--------|-------|
| Email transport | SMTP to `mail.smtp2go.com:2525` | SMTP2GO **HTTP API** (SMTP kept as a fallback) |
| Dispatch channels | Email only | Email + SMS (Clerk Chat) |
| Recipients | Flat list of emails | Recipients **and** an optional supervisor/manager, per channel |
| Record keeping | None — fire and forget | `push_dispatches` rows with per-send `pending` / `sent` / `failed` status |
| Surfaces | Web form only | Web form, preview page, JSON API (v1 + v2), MCP server |

## Moving parts

```
web form ─┐
preview  ─┼─▶ PushDispatcher ─▶ PushDispatch rows (pending) ─▶ PushDispatchJob ─┬─▶ PushMailer ─▶ SMTP2GO API
JSON API ─┤     (validate,          (encrypted destination)      (per row)      └─▶ Sms::ClerkChat ─▶ Clerk Chat
MCP      ─┘      cap, normalise)                                                       │
                                                                          mark_sent! / mark_failed!
```

| File | Role |
|------|------|
| `lib/mail_delivery/smtp2go_api.rb` | ActionMailer delivery method posting to the SMTP2GO v3 API |
| `config/initializers/smtp2go_api.rb` | Registers it as `:smtp2go_api` (inside `to_prepare`, for Zeitwerk) |
| `lib/sms/clerk_chat.rb` | Clerk Chat SMS client |
| `lib/sms/phone_number.rb` | E.164 normalisation of human-typed numbers |
| `app/services/push_dispatcher.rb` | Single entry point: validation, caps, flags, row creation |
| `app/jobs/push_dispatch_job.rb` | Performs one delivery and records the outcome |
| `app/models/push_dispatch.rb` | Delivery row; destination encrypted with Lockbox |
| `app/views/shared/_dispatch_fields.html.erb` | Dispatch fields on all four creation forms |
| `app/views/pushes/_dispatch_now.html.erb` | "Email or text this link" panel on the preview page |
| `app/views/pushes/_dispatch_log.html.erb` | Delivery log on the audit page |

`AutoDispatchJob` was replaced by `PushDispatchJob`; the old job fired
`deliver_later` from inside a job (double-queueing) and had nowhere to record
a failure.

## Design decisions

**Why an HTTP API instead of SMTP.** Outbound SMTP works from the current host, but the API
reports per-recipient failures in the response body, needs no outbound mail port, and removes a
class of TLS/STARTTLS negotiation failures. `delivery_method` remains configurable so SMTP is one
env var away.

**Why rows are created before sending.** `PushDispatcher` writes every `PushDispatch` in
`pending` before enqueueing. A link the operator asked to send is therefore recorded even if the
provider is unreachable and the job never runs.

**Why the job delivers inline.** `PushDispatchJob` calls `message.deliver` with
`raise_delivery_errors` forced on for that one message. `Settings.mail.raise_delivery_errors`
defaults to `false`, which would let a rejected send look successful; forcing it per-message
avoids mutating global state under concurrency.

**Why one SMS per API call.** Clerk Chat accepts a `recipients` array, but a single bad number in
a batch would leave the failure unattributable to a specific `PushDispatch` row.

**Why destinations are encrypted and masked.** Recipient emails and phone numbers are PII. They
are stored via Lockbox (`has_encrypted :destination`) and only ever displayed/returned masked
(`al***@example.com`, `********0817`).

**Why a supervisor gets the real link.** Chosen deliberately over a link-free notification: the
operator's use case is a manager who may need the credential too. The cost is that the supervisor
consumes a view, so the UI warns about the view budget and the mail/SMS say plainly that the
recipient was copied as supervisor.

**Why anonymous callers cannot dispatch.** Otherwise an unauthenticated request could make the
server email or text arbitrary addresses on our infrastructure. Enforced in both the web
controller and the API.

## Settings

```yaml
mail:
  delivery_method: 'smtp'              # or 'smtp2go_api'
  smtp2go_api_url: 'https://api.smtp2go.com/v3/email/send'
  smtp2go_open_timeout: 5
  smtp2go_read_timeout: 15
  # smtp2go_api_key: ''                # PWP__MAIL__SMTP2GO_API_KEY

enable_auto_dispatch: false            # PWP__ENABLE_AUTO_DISPATCH
enable_sms_dispatch: false             # PWP__ENABLE_SMS_DISPATCH

auto_dispatch:
  max_recipients: 10
  max_sms_recipients: 5
  enable_supervisor: true

clerk_chat:
  api_url: 'https://web-api.clerk.chat/public/messages'
  # api_key: ''                        # PWP__CLERK_CHAT__API_KEY
  # sender: '+12819414028'             # PWP__CLERK_CHAT__SENDER
  sent_by_name: 'Password Pusher'
  default_country_code: '1'
  open_timeout: 5
  read_timeout: 15
```

Required production env additions:

```
PWP__MAIL__DELIVERY_METHOD=smtp2go_api
PWP__MAIL__SMTP2GO_API_KEY=<SMTP2GO_API_KEY from ~/.secrets/.env>
PWP__ENABLE_SMS_DISPATCH=true
PWP__CLERK_CHAT__API_KEY=<CLERKCHAT_API_KEY from ~/.secrets/.env>
PWP__CLERK_CHAT__SENDER=+12819414028
```

See `docs/secrets-required.md` for provenance. No secret values live in this repo.

## Mobile UX

Dispatch is the reason to be on a phone, so it is not hidden behind "Additional Options":

- The dispatch card sits outside the collapse on all four creation forms.
- Inputs are `form-control-lg` with `type="email"` / `type="tel"` + `inputmode="tel"` so phones
  raise the right keyboard; form controls are pinned to 16px below `sm` so iOS does not zoom.
- Supervisor fields are collapsed by default (progressive disclosure) with the view-budget
  warning attached.
- The preview page carries a full dispatch panel — create, then text.
- `w-md-75` (new utility in `standard.css`) replaces fixed `w-75` on the secret-URL bar and share
  message so they are full width on a phone.
- The dashboard table is wrapped in `table-responsive`; Kind and Note drop below `md`.

## Testing

```bash
bin/rails test test/lib/mail_delivery test/lib/sms \
  test/services/push_dispatcher_test.rb test/jobs/push_dispatch_job_test.rb \
  test/models/push_dispatch_test.rb test/controllers/push_dispatch_controller_test.rb \
  test/integration/api/api_dispatch_test.rb
```

No test hits a live provider: `Net::HTTP.new` is stubbed for both SMTP2GO and Clerk Chat, and the
mailer failure path swaps in a delivery method that raises.

## Verifying a live instance

```bash
# Email path (sends a real message)
source ~/.secrets/.env
curl -X POST https://api.smtp2go.com/v3/email/send \
  -H 'Content-Type: application/json' -H "X-Smtp2go-Api-Key: $SMTP2GO_API_KEY" \
  -d '{"sender":"PasswordPusher <noreply@aspendora.com>","to":["you@aspendora.com"],
       "subject":"pwpush smoke test","text_body":"ok"}'

# Then end to end, and confirm the delivery log:
curl -X POST https://pwpush.aspendora.com/p/<token>/dispatch.json \
  -H "Content-Type: application/json" \
  -H "X-User-Email: $PWPUSH_USER_EMAIL" -H "X-User-Token: $PWPUSH_USER_TOKEN" \
  -d '{"dispatch": {"emails": ["you@aspendora.com"]}}'

curl https://pwpush.aspendora.com/p/<token>/dispatches.json \
  -H "X-User-Email: $PWPUSH_USER_EMAIL" -H "X-User-Token: $PWPUSH_USER_TOKEN"
```

A dispatch stuck in `pending` means the SolidQueue worker is not running. A `failed` row carries
the provider's own error text — read it before changing anything.

## Related

- API reference: `~/code/apis/pwpush-api/dispatch.md`
- MCP server: `~/code/pwpush-mcp/` and `~/code/apis/pwpush-api/mcp.md`
- Provider docs: `~/code/apis/smtp2go-api/`, `~/code/apis/clerk-chat-api/`
