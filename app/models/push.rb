# frozen_string_literal: true

require "addressable/uri"
require "ipaddr"

# Core model representing a shared secret (text, file, URL, or QR code).
# Pushes auto-expire based on view count and age limits. Content is encrypted
# at rest via Lockbox. Settings are resolved through a priority chain:
# Team Forced > Team Default > User Policy > Global Settings.
class Push < ApplicationRecord
  include WebhookDispatch

  enum :kind, [:text, :file, :url, :qr], validate: true

  validate :check_enabled_push_kinds, on: :create
  validates :url_token, presence: true, uniqueness: true

  validate :check_payload_for_text, if: :text?
  validate :check_optional_files_for_text, if: :text?
  validate :check_files_for_file, if: :file?
  validate :check_payload_for_url, if: :url?
  validate :check_payload_for_qr, if: :qr?

  with_options on: :create do |create|
    create.before_validation :set_expire_limits
    create.before_validation :set_url_token
    create.before_validation :set_default_attributes
  end

  belongs_to :user, optional: true
  belongs_to :request, optional: true
  belongs_to :team, optional: true

  has_encrypted :payload, :note, :passphrase, :file_encryption_key

  has_many :audit_logs, -> { order(created_at: :asc) }, dependent: :destroy
  has_many_attached :files, dependent: :destroy

  def to_param
    url_token.to_s
  end

  def files_encrypted?
    file_encryption_key.present?
  end

  def days_old
    (Time.zone.now.to_datetime - created_at.to_datetime).to_i
  end

  def days_remaining
    [(expire_after_days - days_old), 0].max
  end

  def views_remaining
    [(expire_after_views - view_count), 0].max
  end

  def view_count
    audit_logs.where(kind: %i[view failed_view]).size
  end

  def successful_views
    audit_logs.where(kind: :view).order(:created_at)
  end

  def failed_views
    audit_logs.where(kind: :failed_view).order(:created_at)
  end

  # Expire this push, delete the content and save the record
  def expire
    # Delete content
    self.payload = nil
    self.passphrase = nil
    self.file_encryption_key = nil
    files.purge

    # Mark as expired
    self.expired = true
    self.expired_on = Time.current.utc
    save
  end

  # Override to_json so that we can add in <days_remaining>, <views_remaining>
  # and show the clear push
  def to_json(*args)
    # def to_json(owner: false, payload: false)
    attr_hash = attributes

    owner = false
    payload = false

    owner = args.first[:owner] if args.first.key?(:owner)
    payload = args.first[:payload] if args.first.key?(:payload)

    attr_hash["days_remaining"] = days_remaining
    attr_hash["views_remaining"] = views_remaining
    attr_hash["deleted"] = audit_logs.any?(&:expire?)

    if file?
      file_list = {}
      files.each do |file|
        # Relative path is intentional — API consumers combine with their base URL.
        # Full URLs would require ActionMailer's default_url_options which isn't always configured.
        file_list[file.filename] = Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)
      end
      attr_hash["files"] = file_list.to_json
      attr_hash["files_encrypted"] = files_encrypted?
      attr_hash["file_encryption_key"] = file_encryption_key if files_encrypted? && payload
    end

    # Remove unnecessary fields
    attr_hash.delete("kind")
    attr_hash.delete("payload_ciphertext")
    attr_hash.delete("note_ciphertext")
    attr_hash.delete("passphrase_ciphertext")
    attr_hash.delete("user_id")
    attr_hash.delete("id")

    attr_hash.delete("passphrase")
    attr_hash.delete("name") unless owner
    attr_hash.delete("note") unless owner
    attr_hash.delete("payload") unless payload
    attr_hash.delete("deletable_by_viewer") if url?

    Oj.dump attr_hash
  end

  def ip_allowed?(request_ip)
    return true if allowed_ips.blank?

    allowed_list = allowed_ips.split(/[,\s]+/).map(&:strip).reject(&:blank?)
    return true if allowed_list.empty?

    request_addr = IPAddr.new(request_ip)
    allowed_list.any? do |entry|
      IPAddr.new(entry).include?(request_addr)
    rescue IPAddr::InvalidAddressError
      false
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  def country_allowed?(request_ip)
    return true if allowed_countries.blank?

    allowed_list = allowed_countries.split(/[,\s]+/).map(&:strip).map(&:upcase).reject(&:blank?)
    return true if allowed_list.empty?

    country = GeoipLookup.country_code(request_ip)
    return true if country.nil? # Gracefully allow if lookup fails

    allowed_list.include?(country.upcase)
  end

  def check_optional_files_for_text
    return unless files.attached?

    max = Settings.files.max_file_uploads
    if files.count { |file| !(file.is_a?(String) && file.empty?) } > max
      errors.add(:files, I18n._("You can only attach up to %{count} files per push.") % {count: max})
    end
  end

  def check_files_for_file
    if files.attached? && files.count { |file| !(file.is_a?(String) && file.empty?) } > settings_for_kind.max_file_uploads
      errors.add(:files, I18n._("You can only attach up to %{count} files per push.") % {count: settings_for_kind.max_file_uploads})
    end
  end

  def check_payload_for_text
    # Allow nil payload when expired
    return if expired?

    if payload.blank?
      errors.add(:payload, I18n._("Payload is required."))
      return
    end

    unless payload.is_a?(String) && payload.length.between?(1, 1.megabyte)
      errors.add(:payload, I18n._("The payload is too large.  You can only push up to %{count} bytes.") % {count: 1.megabyte})
    end
  end

  def check_payload_for_url
    # Allow nil payload when expired
    return if expired?

    if payload.present?
      if !valid_url?(payload)
        errors.add(:payload, I18n._("must be a valid HTTP or HTTPS URL."))
      end
    else
      errors.add(:payload, I18n._("Payload is required."))
    end
  end

  def check_payload_for_qr
    # Allow nil payload when expired
    return if expired?

    if payload.present?
      # If the push is a QR code, max payload length is 1024 characters
      if payload.length > 1024
        errors.add(:payload, I18n._("The QR code payload is too large.  You can only push up to %{count} bytes.") % {count: 1024})
      end
    else
      errors.add(:payload, I18n._("Payload is required."))
    end
  end

  def set_expire_limits
    # Settings resolution chain: Team Forced > User Policy > Global Settings
    self.expire_after_days = resolve_setting(:expire_after_days) unless expire_after_days.present? && !team_forces?(:expire_after_days)
    self.expire_after_views = resolve_setting(:expire_after_views) unless expire_after_views.present? && !team_forces?(:expire_after_views)

    unless expire_after_days.between?(settings_for_kind.expire_after_days_min, settings_for_kind.expire_after_days_max)
      self.expire_after_days = settings_for_kind.expire_after_days_default
    end

    unless expire_after_views.between?(settings_for_kind.expire_after_views_min, settings_for_kind.expire_after_views_max)
      self.expire_after_views = settings_for_kind.expire_after_views_default
    end
  end

  def check_limits
    expire if !expired? && (!days_remaining.positive? || !views_remaining.positive?)
  end

  def set_url_token
    self.url_token = SecureRandom.urlsafe_base64(rand(8..14)).downcase
  end

  def expire!
    # Delete content
    self.payload = nil
    self.passphrase = nil
    self.file_encryption_key = nil
    files.purge

    # Mark as expired
    self.expired = true
    self.expired_on = Time.current.utc
    save!
  end

  def settings_for_kind
    if text?
      Settings.pw
    elsif url?
      Settings.url
    elsif file?
      Settings.files
    elsif qr?
      Settings.qr
    end
  end

  def check_enabled_push_kinds
    if kind == "file" && !(Settings.enable_logins && Settings.enable_file_pushes)
      errors.add(:kind, I18n._("File pushes are disabled."))
    end

    if kind == "url" && !(Settings.enable_logins && Settings.enable_url_pushes)
      errors.add(:kind, I18n._("URL pushes are disabled."))
    end

    if kind == "qr" && !(Settings.enable_logins && Settings.enable_qr_pushes)
      errors.add(:kind, I18n._("QR code pushes are disabled."))
    end
  end

  def set_default_attributes
    self.note ||= ""
    self.passphrase ||= ""
    self.name ||= ""
  end

  # --- Policy Resolution ---

  # Resolves a setting using the chain: Team Forced > Team Default > User Policy > Global Settings.
  # Returns the first non-nil value found in the chain, falling back to global defaults.
  def resolve_setting(attribute)
    # 1. Team forced value (if teams enabled and push belongs to a team)
    forced = team_policy_forced_value(attribute)
    return forced if forced

    # 2. Team default (non-forced)
    team_default = team_policy_default(attribute)
    return team_default if team_default

    # 3. User policy default
    user_default = user_policy_default(attribute)
    return user_default if user_default

    # 4. Global Settings default
    settings_for_kind.send("#{attribute}_default")
  end

  # Returns true if the team forces this attribute
  def team_forces?(attribute)
    return false unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
    return false unless team

    team.policy_forced?(user_policy_kind_key, attribute)
  end

  # Returns the team policy default (non-forced) for the attribute, or nil
  def team_policy_default(attribute)
    return nil unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
    return nil unless team

    team.policy_default(user_policy_kind_key, attribute)
  end

  # Returns the forced value from team policy, or nil
  def team_policy_forced_value(attribute)
    return nil unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
    return nil unless team

    team.policy_forced_value(user_policy_kind_key, attribute)
  end

  # Returns the user policy default for the given attribute, if user policies
  # are enabled and the push owner has a policy with a value set.
  # Returns nil to fall back to global Settings.
  def user_policy_default(attribute)
    return nil unless Settings.respond_to?(:enable_user_policies) && Settings.enable_user_policies
    return nil unless user&.user_policy

    user.user_policy.default_for(user_policy_kind_key, attribute)
  end

  # Maps push kind enum ("text", "url", "file", "qr") to the column prefix
  # used in UserPolicy and Team policy hashes (:pw, :url, :file, :qr).
  def user_policy_kind_key
    case kind
    when "text" then :pw
    when "url" then :url
    when "file" then :file
    when "qr" then :qr
    end
  end

  def valid_url?(url)
    !Addressable::URI.parse(url).scheme.nil?
  rescue Addressable::URI::InvalidURIError
    false
  end

  def deleted
    audit_logs.where(kind: AuditLog.kinds[:expire]).exists?
  end
end
