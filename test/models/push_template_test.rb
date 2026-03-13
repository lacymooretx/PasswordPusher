# frozen_string_literal: true

require "test_helper"

class PushTemplateTest < ActiveSupport::TestCase
  setup do
    Settings.enable_push_templates = true
    @user = users(:one)
  end

  teardown do
    Settings.enable_push_templates = false
  end

  test "valid template" do
    template = PushTemplate.new(user: @user, name: "Test", kind: :text, expire_after_days: 5, expire_after_views: 10)
    assert template.valid?
  end

  test "requires name" do
    template = PushTemplate.new(user: @user, kind: :text)
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires unique name per user" do
    PushTemplate.create!(user: @user, name: "Unique", kind: :text)
    duplicate = PushTemplate.new(user: @user, name: "Unique", kind: :text)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "different users can have same name" do
    PushTemplate.create!(user: @user, name: "Shared Name", kind: :text)
    other = users(:giuliana)
    template = PushTemplate.new(user: other, name: "Shared Name", kind: :text)
    assert template.valid?
  end

  test "validates kind enum" do
    template = PushTemplate.new(user: @user, name: "Test", kind: :text)
    assert template.valid?
    template.kind = nil
    assert_not template.valid?
  end

  test "expire_after_days must be positive" do
    template = PushTemplate.new(user: @user, name: "Test", kind: :text, expire_after_days: 0)
    assert_not template.valid?
  end

  test "expire_after_views must be positive" do
    template = PushTemplate.new(user: @user, name: "Test", kind: :text, expire_after_views: -1)
    assert_not template.valid?
  end

  test "available_to includes own templates" do
    templates = PushTemplate.available_to(@user)
    assert templates.where(user: @user).exists?
  end

  test "available_to includes team templates" do
    team_template = push_templates(:team_template)
    templates = PushTemplate.available_to(@user)
    assert_includes templates, team_template
  end

  test "available_to excludes other users templates" do
    other = users(:giuliana)
    other_template = PushTemplate.create!(user: other, name: "Other", kind: :text)
    templates = PushTemplate.available_to(@user)
    assert_not_includes templates, other_template
  end

  test "for_kind scope filters by kind" do
    text_templates = PushTemplate.for_kind(:text)
    text_templates.each { |t| assert_equal "text", t.kind }
  end

  test "validates within global limits" do
    template = PushTemplate.new(
      user: @user, name: "Over Limit", kind: :text,
      expire_after_days: 99999
    )
    assert_not template.valid?
    assert template.errors[:expire_after_days].any?
  end
end
