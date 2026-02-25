# PasswordPusher CLI

Command-line interface for interacting with a PasswordPusher server.

## Installation

```bash
cd tools/cli
bundle install
```

Or install as a gem:

```bash
gem build pwpush-cli.gemspec
gem install pwpush-cli-1.0.0.gem
```

## Configuration

Run interactive setup:

```bash
pwpush config
```

Or set environment variables:

```bash
export PWPUSH_SERVER_URL=https://pwpush.com
export PWPUSH_API_TOKEN=your_api_token
export PWPUSH_EMAIL=your@email.com  # Optional, for legacy auth
```

Configuration is stored in `~/.pwpush.yml`.

## Usage

### Create a text push

```bash
pwpush push "my secret password"
pwpush push "secret" -d 3 -v 5          # 3 days, 5 views
pwpush push "secret" -p mypassphrase    # Passphrase protected
pwpush push "secret" -n "For Bob"       # With a name
```

### Create a URL push

```bash
pwpush url "https://example.com/secret-page"
```

### Create a file push

```bash
pwpush file /path/to/secret.pdf
```

### List pushes

```bash
pwpush list                # Active pushes
pwpush list --expired      # Expired pushes
pwpush list -p 2           # Page 2
```

### Retrieve a push

```bash
pwpush get abc123token
pwpush get abc123token -p mypassphrase
```

### Expire a push

```bash
pwpush expire abc123token
```

### Check version

```bash
pwpush version
```

## Development

```bash
cd tools/cli
bundle install
bundle exec ruby -Itest test/client_test.rb
bundle exec ruby -Itest test/config_test.rb
```
