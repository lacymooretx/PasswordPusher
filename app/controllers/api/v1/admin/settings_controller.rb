# frozen_string_literal: true

# JSON API for viewing and modifying global application settings.
# Token-authenticated via Api::BaseController. Requires admin access.
class Api::V1::Admin::SettingsController < Api::BaseController
  before_action :require_admin

  resource_description do
    name "Admin Settings"
    short "View and modify global application settings."
  end

  api :GET, "/api/v1/admin/settings.json", "List all application settings."
  formats ["JSON"]
  description <<-EOS
    Returns all application settings with their current effective values,
    default values, and any active overrides. Admin access required.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - admin access required."
  def index
    overrides = SettingOverride.all.index_by(&:key)
    settings_hash = flatten_settings(Settings.to_hash)

    result = settings_hash.map do |key, value|
      override = overrides[key]
      {
        key: key,
        value: override ? override.typed_value : value,
        default: value,
        overridden: override.present?,
        value_type: infer_type(value)
      }
    end

    render json: {settings: result}
  end

  api :PATCH, "/api/v1/admin/settings.json", "Bulk update application settings."
  param :settings, Hash, desc: "Hash of setting keys to new values.", required: true
  formats ["JSON"]
  description <<-EOS
    Updates one or more application settings. Each key should use dot notation
    matching the settings hierarchy (e.g. "pw.expire_after_days_default").
    Changes take effect immediately. Admin access required.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - admin access required."
  def update
    settings_params = params.require(:settings).to_unsafe_h

    settings_params.each do |key, value|
      override = SettingOverride.find_or_initialize_by(key: key.to_s)
      override.value = value.to_s
      override.value_type = infer_type_from_value(value)
      override.save!
    end

    SettingOverride.apply_all!

    render json: {message: "Settings updated successfully", updated: settings_params.keys}
  end

  private

  def require_admin
    unless current_user&.admin?
      render json: {error: "Admin access required"}, status: :forbidden
    end
  end

  def flatten_settings(hash, prefix = "")
    hash.each_with_object({}) do |(key, value), result|
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash) || value.is_a?(Config::Options)
        result.merge!(flatten_settings(value.respond_to?(:to_h) ? value.to_h : value, full_key))
      else
        result[full_key] = value
      end
    end
  end

  def infer_type(value)
    case value
    when Integer then "integer"
    when Float then "float"
    when TrueClass, FalseClass then "boolean"
    else "string"
    end
  end

  def infer_type_from_value(value)
    case value
    when Integer then "integer"
    when Float then "float"
    when TrueClass, FalseClass then "boolean"
    when "true", "false" then "boolean"
    when /\A-?\d+\z/ then "integer"
    when /\A-?\d+\.\d+\z/ then "float"
    else "string"
    end
  end
end
