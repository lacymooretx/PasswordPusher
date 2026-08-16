# ClamAV Monitoring

Why file-scanning can fail without anyone noticing, and what now catches it.

Last reviewed: 2026-08-16

## The failure this exists to prevent

On 2026-08-16 `pwpush-clamav` was found to have not scanned a single file since roughly
2026-05-16 — about three months — while `PWP__ENABLE_CLAMAV` was `true` the whole time. Every
layer looked fine:

| Layer | What it showed | Reality |
| --- | --- | --- |
| `docker ps` | `Up 3 months` | PID 1 is `tail -f /dev/null`; a dead clamd never stops the container |
| `docker logs` | `daily.cld updated (version: 28094…)` | that's **freshclam**, the updater — not the scanner |
| Push UI | uploads succeed, links work | scanning happens in a background job, after the push is live |
| `FileScanJob` | nothing in the logs | it retried 3× then discarded the job silently |

The only honest signals were the container healthcheck (`unhealthy`, failing streak 129,480) and
one easily-missed log line: `WARNING: Clamd was NOT notified: ... Connection refused`.

`clamd` itself was a **zombie** — `ps` showed `[clamd]` with `RSS 0`, `State: Z`.

Detection was never the problem. **Alerting was.**

## What now exists

### `ClamavHealthCheckJob`

Runs every 15 minutes in production (`config/recurring.yml`), probes `ClamavScanner.available?`,
and emails administrators when the daemon cannot be reached.

State lives in `Rails.cache` under one key, `clamav_health:state`:

```ruby
{down_since: Time, alerted_at: Time}
```

- **`down_since`** starts a grace period, so a routine clamd restart (~20s) never pages anyone.
- **`alerted_at`** throttles reminders to one per `realert_after_hours`, and its presence is what
  makes a recovery notice appropriate — "recovered" is only sent if "down" was actually sent.

### `FileScanJob` no longer gives up quietly

Exhausting `retry_on ClamavScanner::ConnectionError` now logs at **error** level, naming the push
and stating plainly that the file is live and `UNSCANNED`, then enqueues `ClamavHealthCheckJob` so
an alert follows the same throttle.

It deliberately does **not** expire the push. Fail-open vs fail-closed for unscanned files is a
policy decision — see *Open question* below.

## Configuration

Under `clamav.health_check` in `config/settings.yml`:

| Setting | Default | Env override |
| --- | --- | --- |
| `enabled` | `true` | `PWP__CLAMAV__HEALTH_CHECK__ENABLED` |
| `grace_period_minutes` | `5` | `PWP__CLAMAV__HEALTH_CHECK__GRACE_PERIOD_MINUTES` |
| `realert_after_hours` | `6` | `PWP__CLAMAV__HEALTH_CHECK__REALERT_AFTER_HOURS` |
| `alert_emails` | `[]` | `PWP__CLAMAV__HEALTH_CHECK__ALERT_EMAILS` |

The whole probe is inert unless `enable_clamav` is true.

**Recipients:** `alert_emails` if set, otherwise every user with `admin: true`. The YAML form is a
list; the env override is one comma-separated string. Both are accepted — there are tests for each,
because the Config gem parses env values as YAML and that has bitten this project before.

## Two deliberate design choices

**Over-alerting is preferred to under-alerting.** The production cache is a file store that
`CleanupCacheJob` prunes every 24h. If the state key is swept mid-outage you get one extra "down"
email and lose the "recovered" notice. That's the cheap direction to fail when the alternative is
silently unscanned files.

**A non-functional cache degrades to alerting, not to silence.** Both the grace period and the
throttle depend on state surviving between runs. With a store that retains nothing (`:null_store`,
a broken Redis) every run would look like a brand-new outage, so a naive implementation would sit
inside the grace period forever and **never alert** — reproducing the exact bug this job exists to
catch. The job round-trip-probes the cache; if state isn't retained it logs an error and alerts on
every probe. There's a regression test for this.

## Verifying it by hand

```bash
# Is the daemon actually alive? (the container being "Up" proves nothing)
docker exec pwpush-clamav ps -o pid,rss,args      # [clamd] with RSS 0 => zombie
docker exec pwpush-clamav sh -c 'netstat -ltn | grep 3310'

# What the app sees
docker exec pwpush bin/rails runner 'puts ClamavScanner.available?'

# Force a probe now
docker exec pwpush bin/rails runner 'ClamavHealthCheckJob.perform_now'

# Count past silent failures
docker exec pwpush bin/rails runner '
  puts SolidQueue::FailedExecution.joins(:job)
         .where("solid_queue_jobs.class_name = ?", "FileScanJob").count'
```

**Verify a fix with EICAR, not with a port check** — a listening socket does not prove the
signature database loaded. Pipe the script via stdin to avoid shell-quoting problems:

```bash
ssh docker-apps 'docker exec -i pwpush bin/rails runner -' <<'RUBY'
eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$" + "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!" + "$H+H*"
puts ClamavScanner.scan(eicar).inspect   # expect clean=false, virus="Eicar-Test-Signature"
RUBY
```

## Recovering the daemon

```bash
docker restart pwpush-clamav     # clamd listens again in ~18s, ~955MB RSS
```

Root cause of the original death was never established — `dmesg` had rotated after three months.
clamd holds ~1GB RSS on a host that often runs low on free memory, so OOM remains the leading
theory. **Expect recurrence**; that is precisely why the alert exists.

## Open question, for a human to decide

While the scanner is down, file pushes are accepted and served **unscanned** (fail-open). Making
them fail-closed — refusing uploads, or auto-expiring pushes that could not be scanned — would
close the gap but breaks file sharing whenever ClamAV hiccups. That trade-off has not been made;
today's behaviour is fail-open plus a loud alert.
