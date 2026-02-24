# frozen_string_literal: true

module PushesHelper
  def filesize(size)
    units = %w[B KiB MiB GiB TiB Pib EiB ZiB]

    return "0.0 B" if size.zero?

    exp = (Math.log(size) / Math.log(1024)).to_i
    exp += 1 if size.to_f / (1024**exp) >= 1024 - 0.05
    exp = units.size - 1 if exp > units.size - 1

    format("%.1f #{units[exp]}", size.to_f / (1024**exp))
  end

  # --- User Policy Defaults ---

  # Returns the effective default for a push setting, checking user policy first
  # then falling back to the global Settings value.
  #
  # kind_settings: the Settings object for this kind (e.g. Settings.pw)
  # setting_name: the setting attribute name (e.g. :expire_after_days_default)
  # push_kind: the push kind string ("text", "url", "file", "qr")
  #
  # For user policy, maps setting_name to policy column:
  #   expire_after_days_default -> expire_after_days
  #   expire_after_views_default -> expire_after_views
  #   retrieval_step_default -> retrieval_step
  #   deletable_pushes_default -> deletable_by_viewer
  def effective_default(kind_settings, setting_name, push_kind = "text")
    if user_signed_in? && Settings.respond_to?(:enable_user_policies) && Settings.enable_user_policies
      policy = current_user.user_policy
      if policy
        kind_key = case push_kind
        when "text" then :pw
        when "url" then :url
        when "file" then :file
        when "qr" then :qr
        end

        # Map settings name to policy column attribute
        policy_attr = case setting_name.to_s
        when "expire_after_days_default" then :expire_after_days
        when "expire_after_views_default" then :expire_after_views
        when "retrieval_step_default" then :retrieval_step
        when "deletable_pushes_default" then :deletable_by_viewer
        end

        if policy_attr
          val = policy.default_for(kind_key, policy_attr)
          return val unless val.nil?
        end
      end
    end
    kind_settings.send(setting_name)
  end

  # Returns HTML options hash for checkbox form controls with cookie persistence support
  # For new pushes (not persisted), includes x-default attribute to enable cookie loading
  # For existing pushes, omits x-default so server values are preserved
  def checkbox_options_for_push(push, target_name, default_value)
    base_options = {
      :class => "form-check-input flex-shrink-0",
      "data-knobs-target" => "#{target_name}Checkbox"
    }

    if push.persisted?
      base_options
    else
      base_options.merge("x-default" => default_value)
    end
  end
end
