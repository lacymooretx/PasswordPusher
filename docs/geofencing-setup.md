# Geofencing Setup Guide

PasswordPusher's geofencing feature restricts push access by country using MaxMind's GeoLite2 database.

## Prerequisites

- PasswordPusher with `enable_geofencing` feature flag
- A MaxMind GeoLite2-Country database file (`.mmdb`)

## 1. Obtain the MaxMind GeoLite2-Country Database

1. Create a free MaxMind account at https://www.maxmind.com/en/geolite2/signup
2. After verifying your email, log in to https://www.maxmind.com/en/accounts/current/people/current
3. Navigate to **GeoIP2 / GeoLite2** > **Download Files**
4. Download **GeoLite2 Country** in MaxMind DB format (`.mmdb`)
5. Extract the archive — you need the `GeoLite2-Country.mmdb` file

## 2. Place the Database File

Choose a persistent location outside the application directory:

```bash
# Linux / production server
sudo mkdir -p /opt/maxmind
sudo cp GeoLite2-Country.mmdb /opt/maxmind/

# macOS / development
mkdir -p ~/maxmind
cp GeoLite2-Country.mmdb ~/maxmind/
```

## 3. Configure PasswordPusher

Set the environment variables:

```bash
PWP__ENABLE_GEOFENCING='true'
PWP__GEOFENCING__DATABASE_PATH='/opt/maxmind/GeoLite2-Country.mmdb'
```

Or in `config/settings.yml` / `config/settings.local.yml`:

```yaml
enable_geofencing: true
geofencing:
  database_path: '/opt/maxmind/GeoLite2-Country.mmdb'
```

## 4. Country Code Format

Geofencing uses **ISO 3166-1 alpha-2** country codes (two-letter uppercase).

Examples:
- `US` — United States
- `GB` — United Kingdom
- `DE` — Germany
- `JP` — Japan
- `AU` — Australia

When creating a push with geofencing, users enter comma-separated country codes in the `allowed_countries` field (e.g., `US, CA, GB`).

Full list: https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2

## 5. Docker Deployment

Mount the database file as a volume in your container:

```yaml
# docker-compose.yml
services:
  app:
    image: pwpush/pwpush:latest
    environment:
      PWP__ENABLE_GEOFENCING: 'true'
      PWP__GEOFENCING__DATABASE_PATH: '/data/GeoLite2-Country.mmdb'
    volumes:
      - /opt/maxmind/GeoLite2-Country.mmdb:/data/GeoLite2-Country.mmdb:ro
```

## 6. Database Updates

MaxMind updates GeoLite2 databases approximately every two weeks. To keep your geofencing accurate:

### Manual Updates

Download the latest database from your MaxMind account and replace the file. No application restart is required — the file is read on each lookup.

### Automated Updates with geoipupdate

MaxMind provides the `geoipupdate` tool for automatic updates:

```bash
# Install (Ubuntu/Debian)
sudo add-apt-repository ppa:maxmind/ppa
sudo apt update
sudo apt install geoipupdate

# Install (macOS)
brew install geoipupdate
```

Configure `/etc/GeoIP.conf`:

```
AccountID YOUR_ACCOUNT_ID
LicenseKey YOUR_LICENSE_KEY
EditionIDs GeoLite2-Country
DatabaseDirectory /opt/maxmind
```

Add a cron job to update weekly:

```bash
# crontab -e
0 3 * * 3 /usr/bin/geoipupdate
```

### Generate a License Key

1. Log in to your MaxMind account
2. Go to **Manage License Keys**
3. Click **Generate New License Key**
4. Select "GeoIP Update" as the purpose

## 7. Graceful Degradation

If the database file is missing or unreadable, geofencing checks are **skipped** (access is allowed). This prevents lockouts if the database file becomes unavailable. Check your application logs for warnings about missing database files.

## 8. Testing

Verify geofencing is working:

```bash
# Create a push restricted to US only
curl -X POST \
  -H "X-User-Email: user@example.com" \
  -H "X-User-Token: MyAPIToken" \
  -H "Content-Type: application/json" \
  -d '{"password": {"payload": "geo-test", "allowed_countries": "US"}}' \
  https://your-instance.com/p.json
```

Accessing from a non-US IP will return `403 Forbidden`.
