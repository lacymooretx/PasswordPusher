# frozen_string_literal: true

# Turns an operator-supplied "send this secret to..." request into PushDispatch
# rows plus queued delivery jobs.
#
# Single entry point for every surface -- the web form, the JSON API and the MCP
# server all call PushDispatcher.call, so limits, feature flags, validation and
# the audit trail behave identically no matter where the request came from.
#
# Nothing here talks to a provider: rows are created in the +pending+ state and
# PushDispatchJob performs the actual send. A dispatch the operator asked for is
# therefore recorded even if the provider is down.
class PushDispatcher
  # +dispatches+ are the persisted rows, +errors+ are inputs we refused (bad
  # address, over the limit, channel disabled) reported back to the caller.
  Result = Struct.new(:dispatches, :errors, keyword_init: true) do
    def any?
      dispatches.any?
    end

    def email_count
      dispatches.count(&:email?)
    end

    def sms_count
      dispatches.count(&:sms?)
    end
  end

  # spec accepts either comma/semicolon/space separated strings (what the form
  # posts) or arrays (what the JSON API and MCP post).
  #
  #   emails:            recipient email address(es)
  #   phones:            recipient mobile number(s)
  #   supervisor_email:  optional single supervisor/manager address
  #   supervisor_phone:  optional single supervisor/manager mobile number
  def self.call(push:, secret_url:, spec:, enqueue: true)
    new(push: push, secret_url: secret_url, spec: spec).call(enqueue: enqueue)
  end

  def initialize(push:, secret_url:, spec:)
    @push = push
    @secret_url = secret_url
    @spec = (spec || {}).symbolize_keys
    @errors = []
    @dispatches = []
  end

  def call(enqueue: true)
    return Result.new(dispatches: [], errors: ["Auto dispatch is not enabled."]) unless dispatch_enabled?

    build_email_dispatches
    build_sms_dispatches

    @dispatches.each { |d| PushDispatchJob.perform_later(d.id, @secret_url) } if enqueue

    Result.new(dispatches: @dispatches, errors: @errors)
  end

  # Body of the SMS carrying the secret link. Deliberately terse: carriers split
  # at 160 GSM-7 characters and each segment is billed. The passphrase itself is
  # never included -- that would defeat the second factor.
  def self.sms_body(push, secret_url, role: :recipient)
    brand = Settings.brand.title
    sender = push.user&.email.presence || brand

    lines = []
    lines << if role.to_s == "supervisor"
      "#{sender} shared a secret via #{brand} and copied you as supervisor."
    else
      "#{sender} shared a secret with you via #{brand}."
    end
    lines << secret_url

    limits = []
    limits << "#{push.expire_after_days} day(s)" if push.expire_after_days.to_i.positive?
    limits << "#{push.expire_after_views} view(s)" if push.expire_after_views.to_i.positive?
    lines << "Expires after #{limits.join(" or ")}." if limits.any?

    lines << "A passphrase is required - ask the sender." if push.passphrase.present?

    lines.join("\n")
  end

  private

  def dispatch_enabled?
    Settings.respond_to?(:enable_auto_dispatch) && Settings.enable_auto_dispatch
  end

  def sms_enabled?
    Settings.respond_to?(:enable_sms_dispatch) && Settings.enable_sms_dispatch
  end

  def supervisor_enabled?
    return true unless Settings.respond_to?(:auto_dispatch) && Settings.auto_dispatch
    return true unless Settings.auto_dispatch.respond_to?(:enable_supervisor)
    Settings.auto_dispatch.enable_supervisor
  end

  def max_emails
    Settings.auto_dispatch&.max_recipients || 10
  end

  def max_sms
    return 5 unless Settings.auto_dispatch.respond_to?(:max_sms_recipients)
    Settings.auto_dispatch.max_sms_recipients || 5
  end

  # -- email --------------------------------------------------------------

  def build_email_dispatches
    emails = valid_emails(tokenize(@spec[:emails]))

    if emails.size > max_emails
      @errors << "Only the first #{max_emails} email recipient(s) were dispatched."
      emails = emails.first(max_emails)
    end

    emails.each { |address| create_dispatch(:email, :recipient, address) }

    supervisor = @spec[:supervisor_email].to_s.strip
    return if supervisor.blank?

    unless supervisor_enabled?
      @errors << "Supervisor dispatch is not enabled."
      return
    end

    if valid_email?(supervisor)
      create_dispatch(:email, :supervisor, supervisor)
    else
      @errors << "Supervisor email address is not valid: #{supervisor}"
    end
  end

  # -- sms ----------------------------------------------------------------

  def build_sms_dispatches
    phones = Sms::PhoneNumber.normalize_list(@spec[:phones])
    supervisor_raw = @spec[:supervisor_phone].to_s.strip

    if phones.empty? && supervisor_raw.blank?
      report_unparseable_phones
      return
    end

    unless sms_enabled?
      @errors << "SMS dispatch is not enabled."
      return
    end

    report_unparseable_phones

    if phones.size > max_sms
      @errors << "Only the first #{max_sms} SMS recipient(s) were dispatched."
      phones = phones.first(max_sms)
    end

    phones.each { |number| create_dispatch(:sms, :recipient, number) }

    return if supervisor_raw.blank?

    unless supervisor_enabled?
      @errors << "Supervisor dispatch is not enabled."
      return
    end

    supervisor = Sms::PhoneNumber.normalize(supervisor_raw)
    if supervisor
      create_dispatch(:sms, :supervisor, supervisor)
    else
      @errors << "Supervisor mobile number is not valid: #{supervisor_raw}"
    end
  end

  # A number the operator typed that we could not turn into E.164 is a silent
  # non-delivery unless we say so.
  def report_unparseable_phones
    raw = tokenize(@spec[:phones])
    bad = raw.reject { |t| Sms::PhoneNumber.valid?(t) }
    bad.each { |t| @errors << "Mobile number is not valid: #{t}" }
  end

  # -- shared -------------------------------------------------------------

  def create_dispatch(channel, role, destination)
    @dispatches << PushDispatch.create!(
      push: @push,
      channel: channel,
      role: role,
      status: :pending,
      destination: destination
    )
  end

  def tokenize(value)
    return [] if value.blank?
    tokens = value.is_a?(Array) ? value : value.to_s.split(/[,;\s]+/)
    tokens.map { |t| t.to_s.strip }.reject(&:blank?).uniq
  end

  def valid_emails(tokens)
    tokens.select do |token|
      if valid_email?(token)
        true
      else
        @errors << "Email address is not valid: #{token}"
        false
      end
    end
  end

  def valid_email?(value)
    value.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
