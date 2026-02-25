# frozen_string_literal: true

# Apply database-backed setting overrides after Rails initialization.
# This allows runtime configuration changes to take effect on boot.
Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection.table_exists?(:setting_overrides)
    SettingOverride.apply_all!
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Database not yet created or migrated — skip
end
