# frozen_string_literal: true

# Database-backed override layer for runtime settings changes.
# Keys use dot-notation matching Config gem paths (e.g. "pw.expire_after_days_default").
# apply_all! walks all overrides and mutates Settings in-place.
class SettingOverride < ApplicationRecord
  VALUE_TYPES = %w[string integer boolean float].freeze

  validates :key, presence: true, uniqueness: true
  validates :value_type, presence: true, inclusion: {in: VALUE_TYPES}

  def typed_value
    case value_type
    when "integer" then value.to_i
    when "float" then value.to_f
    when "boolean" then ActiveModel::Type::Boolean.new.cast(value)
    else value
    end
  end

  def self.apply_all!
    find_each do |override|
      keys = override.key.split(".")
      if keys.length == 1
        Settings[keys.first] = override.typed_value
      else
        target = Settings
        keys[0..-2].each do |k|
          target = target[k]
          break if target.nil?
        end
        target[keys.last] = override.typed_value if target
      end
    end
  end
end
