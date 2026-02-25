# frozen_string_literal: true

require "test_helper"

class SettingOverrideTest < ActiveSupport::TestCase
  teardown do
    SettingOverride.delete_all
  end

  test "validates key presence" do
    override = SettingOverride.new(value: "test", value_type: "string")
    assert_not override.valid?
    assert_includes override.errors[:key], "can't be blank"
  end

  test "validates key uniqueness" do
    SettingOverride.create!(key: "enable_logins", value: "true", value_type: "boolean")
    duplicate = SettingOverride.new(key: "enable_logins", value: "false", value_type: "boolean")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "validates value_type inclusion" do
    override = SettingOverride.new(key: "test_key", value: "val", value_type: "invalid")
    assert_not override.valid?
    assert_includes override.errors[:value_type], "is not included in the list"
  end

  test "typed_value casts string" do
    override = SettingOverride.new(key: "test", value: "hello", value_type: "string")
    assert_equal "hello", override.typed_value
  end

  test "typed_value casts integer" do
    override = SettingOverride.new(key: "test", value: "42", value_type: "integer")
    assert_equal 42, override.typed_value
  end

  test "typed_value casts boolean true" do
    override = SettingOverride.new(key: "test", value: "true", value_type: "boolean")
    assert_equal true, override.typed_value
  end

  test "typed_value casts boolean false" do
    override = SettingOverride.new(key: "test", value: "false", value_type: "boolean")
    assert_equal false, override.typed_value
  end

  test "typed_value casts float" do
    override = SettingOverride.new(key: "test", value: "3.14", value_type: "float")
    assert_in_delta 3.14, override.typed_value
  end

  test "apply_all updates top-level settings" do
    original = Settings.enable_logins
    SettingOverride.create!(key: "enable_logins", value: "true", value_type: "boolean")
    SettingOverride.apply_all!
    assert_equal true, Settings.enable_logins
    Settings.enable_logins = original
  end

  test "apply_all updates nested settings" do
    original = Settings.pw.expire_after_days_default
    SettingOverride.create!(key: "pw.expire_after_days_default", value: "25", value_type: "integer")
    SettingOverride.apply_all!
    assert_equal 25, Settings.pw.expire_after_days_default
    # Reset
    Settings.pw.expire_after_days_default = original
  end
end
