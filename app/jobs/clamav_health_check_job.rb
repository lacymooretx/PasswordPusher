# frozen_string_literal: true

# Periodically verifies that the ClamAV daemon is actually reachable, and alerts
# administrators when it is not.
#
# Why this exists: clamd can die while its container keeps reporting "Up" (PID 1
# in the official image is a `tail -f /dev/null`, so a dead clamd never takes the
# container down), and freshclam carries on updating signatures so the logs still
# look healthy. Meanwhile FileScanJob runs *after* a push is already live and
# gives up after a few connection errors, silently. The net effect is that file
# pushes sail through completely unscanned while `enable_clamav` is true and
# everyone assumes files are being checked. That went unnoticed for ~3 months.
#
# Detection was never the problem -- alerting was. This job closes that gap.
#
# State is kept in Rails.cache under a single key:
#
#   {down_since: Time, alerted_at: Time}
#
# - `down_since` starts the grace period, so a blip during a clamd restart
#   (~20s) never pages anyone.
# - `alerted_at` throttles repeat mail to one per `realert_after_hours`, and its
#   presence is what makes a recovery notice appropriate -- we only announce
#   "recovered" if we actually announced "down".
#
# Cache caveat: the production cache is a file store that CleanupCacheJob prunes
# every 24h. If the state key is swept while ClamAV is still down, the effect is
# one extra "down" email (and a missed "recovered" notice). That direction of
# failure is deliberate -- over-alerting on an unscanned-file condition is much
# cheaper than under-alerting.
class ClamavHealthCheckJob < ApplicationJob
  queue_as :default

  STATE_KEY = "clamav_health:state"
  STATE_TTL = 30.days

  DEFAULT_GRACE_PERIOD_MINUTES = 5
  DEFAULT_REALERT_AFTER_HOURS = 6

  def perform
    return unless enabled?

    if scanner_available?
      handle_recovery
    else
      handle_outage
    end
  end

  private

  def enabled?
    return false unless Settings.respond_to?(:enable_clamav) && Settings.enable_clamav
    return true unless health_check_settings.respond_to?(:enabled)

    health_check_settings.enabled
  end

  # ClamavScanner.available? already swallows every exception and returns false,
  # but guard anyway so a surprise here can never take the recurring queue down.
  def scanner_available?
    ClamavScanner.available?
  rescue => e
    Rails.logger.error("ClamavHealthCheckJob: availability probe raised #{e.class}: #{e.message}")
    false
  end

  def handle_recovery
    state = read_state
    return if state.empty?

    if state[:alerted_at]
      downtime = distance_in_words(state[:down_since], Time.current)
      Rails.logger.warn("ClamavHealthCheckJob: ClamAV recovered after #{downtime}")
      deliver(:clamav_recovered, down_since: state[:down_since], downtime: downtime)
    end

    Rails.cache.delete(STATE_KEY)
  end

  def handle_outage
    state = read_state
    now = Time.current
    down_since = state[:down_since] || now

    Rails.logger.error(
      "ClamavHealthCheckJob: ClamAV unreachable at #{scanner_target} " \
      "(down since #{format_time(down_since)}) -- file pushes are NOT being scanned"
    )

    # Both the grace period and the re-alert throttle depend on state surviving
    # between runs. If the cache silently drops it (a null store, a broken Redis)
    # every run would look like a brand new outage and we would sit inside the
    # grace period forever, never alerting -- precisely the silent failure this
    # job exists to prevent. Degrade loudly instead: alert every probe.
    unless cache_retains_state?
      Rails.logger.error(
        "ClamavHealthCheckJob: cache (#{Rails.cache.class}) is not retaining state, so the " \
        "grace period and re-alert throttle cannot be applied -- alerting on every probe"
      )
      deliver(:clamav_unavailable, down_since: down_since, downtime: distance_in_words(down_since, now))
      return
    end

    if alert_due?(state, down_since, now)
      deliver(:clamav_unavailable, down_since: down_since, downtime: distance_in_words(down_since, now))
      state[:alerted_at] = now
    end

    state[:down_since] = down_since
    Rails.cache.write(STATE_KEY, state, expires_in: STATE_TTL)
  end

  def alert_due?(state, down_since, now)
    return false if now - down_since < grace_period
    return true if state[:alerted_at].nil?

    now - state[:alerted_at] >= realert_after
  end

  def deliver(action, **params)
    to = recipients
    if to.empty?
      Rails.logger.warn("ClamavHealthCheckJob: no alert recipients configured and no admin users found; " \
                        "set clamav.health_check.alert_emails or flag a user as admin")
      return
    end

    AdminMailer.public_send(action, to, target: scanner_target, **params).deliver_later
  rescue => e
    # Never let a mail failure crash the recurring queue -- the log line above
    # is the backstop.
    Rails.logger.error("ClamavHealthCheckJob: failed to send #{action} alert: #{e.class}: #{e.message}")
  end

  def recipients
    configured = Array(health_check_settings.respond_to?(:alert_emails) ? health_check_settings.alert_emails : nil)
      .flat_map { |entry| entry.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)

    return configured if configured.any?

    User.where(admin: true).pluck(:email).compact
  end

  def read_state
    state = Rails.cache.read(STATE_KEY)
    state.is_a?(Hash) ? state.symbolize_keys : {}
  end

  # Round-trip probe: a null store accepts writes and returns nil on read.
  def cache_retains_state?
    return @cache_retains_state unless @cache_retains_state.nil?

    probe_key = "#{STATE_KEY}:probe"
    Rails.cache.write(probe_key, "ok", expires_in: 1.minute)
    @cache_retains_state = (Rails.cache.read(probe_key) == "ok")
  rescue => e
    Rails.logger.error("ClamavHealthCheckJob: cache probe raised #{e.class}: #{e.message}")
    @cache_retains_state = false
  end

  def health_check_settings
    @health_check_settings ||=
      if Settings.respond_to?(:clamav) && Settings.clamav.respond_to?(:health_check)
        Settings.clamav.health_check
      else
        Config::Options.new
      end
  end

  def grace_period
    minutes = if health_check_settings.respond_to?(:grace_period_minutes)
      health_check_settings.grace_period_minutes
    end
    (minutes || DEFAULT_GRACE_PERIOD_MINUTES).to_i.minutes
  end

  def realert_after
    hours = if health_check_settings.respond_to?(:realert_after_hours)
      health_check_settings.realert_after_hours
    end
    (hours || DEFAULT_REALERT_AFTER_HOURS).to_i.hours
  end

  def scanner_target
    host = ENV["PWP__CLAMAV__HOST"] || (Settings.clamav.respond_to?(:host) ? Settings.clamav.host : "localhost")
    port = ENV["PWP__CLAMAV__PORT"] || (Settings.clamav.respond_to?(:port) ? Settings.clamav.port : 3310)
    "#{host}:#{port}"
  end

  def distance_in_words(from, to)
    return "an unknown period" if from.blank?

    ActionController::Base.helpers.distance_of_time_in_words(from, to)
  end

  def format_time(time)
    time.in_time_zone("America/Chicago").strftime("%Y-%m-%d %H:%M %Z")
  end
end
