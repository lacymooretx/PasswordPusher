# Ruby Setup for PasswordPusher Development

This project requires **Ruby 4.0.1** (specified in `.ruby-version`).

## macOS Setup (chruby + ruby-install)

This project uses [chruby](https://github.com/postmodern/chruby) for Ruby version management and [ruby-install](https://github.com/postmodern/ruby-install) for building Ruby versions.

### Install chruby and ruby-install

```bash
brew install chruby ruby-install
```

### Install Ruby 4.0.1

```bash
ruby-install ruby 4.0.1
```

This compiles Ruby from source — it may take 5-10 minutes.

### Activate chruby in Your Shell

Add to your `~/.zshrc` (or `~/.bashrc`):

```bash
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
```

The `auto.sh` script automatically switches Ruby versions based on `.ruby-version` files. When you `cd` into the project directory, chruby will switch to Ruby 4.0.1 automatically.

### Verify

```bash
# Reload your shell
exec $SHELL

# Navigate to the project
cd /path/to/PasswordPusher

# Confirm Ruby version
ruby --version
# => ruby 4.0.1 (2026-01-13 revision e04267a14b) +PRISM [arm64-darwin25]
```

### Switching Manually

If auto-switching is not enabled, activate Ruby 4.0.1 manually:

```bash
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
chruby ruby-4.0.1
```

### List Available Rubies

```bash
chruby
```

## Install Dependencies

After switching to Ruby 4.0.1:

```bash
gem install bundler
bundle install
yarn install
```

## Common Commands

```bash
bin/dev              # Start dev server (port 5100)
bin/rails test       # Run all tests
bundle exec rubocop  # Ruby linter
bundle exec erblint --lint-all  # ERB linter
bundle exec brakeman # Security scanner
```

## Troubleshooting

### "Could not find 'bundler' (4.0.4)"

You're running system Ruby (2.6) instead of Ruby 4.0.1. Make sure chruby is loaded:

```bash
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
chruby ruby-4.0.1
```

### Ruby not found after install

If `ruby-install` succeeded but `chruby` doesn't list it, reload your shell:

```bash
exec $SHELL
chruby
```

The installed Ruby lives at `~/.rubies/ruby-4.0.1/`.
