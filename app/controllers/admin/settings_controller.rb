# frozen_string_literal: true

module Admin
  class SettingsController < ::AdminController
    SETTING_SECTIONS = {
      "Feature Flags" => %w[
        enable_logins enable_user_policies enable_two_factor enable_user_branding
        enable_requests enable_teams enable_audit_dashboard enable_push_notifications
        enable_webhooks enable_ip_allowlisting enable_geofencing enable_file_pushes
        enable_url_pushes enable_qr_pushes allow_anonymous disable_signups
      ],
      "Server" => %w[
        host_domain host_protocol override_base_url login_session_timeout
      ],
      "Push Defaults (pw)" => %w[
        pw.expire_after_days_default pw.expire_after_days_min pw.expire_after_days_max
        pw.expire_after_views_default pw.expire_after_views_min pw.expire_after_views_max
        pw.retrieval_step_default pw.deletable_pushes_default
      ],
      "Push Defaults (url)" => %w[
        url.expire_after_days_default url.expire_after_days_min url.expire_after_days_max
        url.expire_after_views_default url.expire_after_views_min url.expire_after_views_max
        url.retrieval_step_default url.deletable_pushes_default
      ],
      "Push Defaults (file)" => %w[
        files.expire_after_days_default files.expire_after_days_min files.expire_after_days_max
        files.expire_after_views_default files.expire_after_views_min files.expire_after_views_max
        files.retrieval_step_default files.deletable_pushes_default
      ],
      "Push Defaults (qr)" => %w[
        qr.expire_after_days_default qr.expire_after_days_min qr.expire_after_days_max
        qr.expire_after_views_default qr.expire_after_views_min qr.expire_after_views_max
        qr.retrieval_step_default qr.deletable_pushes_default
      ],
      "Branding" => %w[
        brand.title brand.tagline
        brand.disclaimer brand.show_footer_menu
      ],
      "Mail / SMTP" => %w[
        mail.raise_delivery_errors mail.smtp_address mail.smtp_port
        mail.smtp_user_name mail.smtp_domain mail.smtp_authentication
        mail.smtp_starttls mail.smtp_enable_starttls_auto
        mail.smtp_open_timeout mail.smtp_read_timeout mail.mailer_sender
      ],
      "Webhooks" => %w[
        webhooks.max_per_user webhooks.max_failures webhooks.retry_attempts
        webhooks.delivery_retention_days
      ]
    }.freeze

    def index
      @overrides = SettingOverride.all.index_by(&:key)
      @sections = SETTING_SECTIONS
    end

    def update
      settings_data = params[:settings] || {}

      settings_data.each do |key, value|
        override = SettingOverride.find_or_initialize_by(key: key)
        override.value = value.to_s
        override.value_type = infer_type(key, value)
        override.save!
      end

      SettingOverride.apply_all!

      redirect_to admin_settings_path, notice: "Settings updated successfully."
    end

    private

    def infer_type(key, value)
      current = resolve_setting(key)
      case current
      when TrueClass, FalseClass then "boolean"
      when Integer then "integer"
      when Float then "float"
      else
        # Check if the value looks like a boolean
        if %w[true false 1 0].include?(value.to_s.downcase)
          "boolean"
        elsif value.to_s.match?(/\A-?\d+\z/)
          "integer"
        elsif value.to_s.match?(/\A-?\d+\.\d+\z/)
          "float"
        else
          "string"
        end
      end
    end

    def resolve_setting(key)
      keys = key.split(".")
      target = Settings
      keys.each do |k|
        return nil unless target.respond_to?(:[])
        target = target[k]
      end
      target
    end

    helper_method :setting_value, :setting_default, :setting_env_var

    def setting_value(key)
      if @overrides[key]
        @overrides[key].typed_value
      else
        resolve_setting(key)
      end
    end

    def setting_default(key)
      resolve_setting(key)
    end

    def setting_env_var(key)
      "PWP__#{key.tr(".", "__").upcase}"
    end
  end
end
