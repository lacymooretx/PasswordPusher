# frozen_string_literal: true

require "test_helper"

class UserBrandingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "should create user branding" do
    branding = UserBranding.new(
      user: @user,
      delivery_heading: "Secure from Acme",
      primary_color: "#336699"
    )
    assert branding.save
  end

  test "should enforce uniqueness per user" do
    UserBranding.create!(user: @user, delivery_heading: "Test")
    duplicate = UserBranding.new(user: @user, delivery_heading: "Another")
    assert_not duplicate.valid?
  end

  test "validates hex color format" do
    branding = UserBranding.new(user: @user, primary_color: "not-a-color")
    assert_not branding.valid?
    assert branding.errors[:primary_color].any?
  end

  test "allows valid hex colors" do
    branding = UserBranding.new(user: @user, primary_color: "#ff0000", background_color: "#ffffff")
    assert branding.valid?
  end

  test "allows blank colors" do
    branding = UserBranding.new(user: @user, primary_color: "", background_color: "")
    assert branding.valid?
  end

  test "validates heading length" do
    branding = UserBranding.new(user: @user, delivery_heading: "a" * 201)
    assert_not branding.valid?
    assert branding.errors[:delivery_heading].any?
  end

  test "user has_one user_branding" do
    branding = UserBranding.create!(user: @user, delivery_heading: "Test")
    assert_equal branding, @user.reload.user_branding
  end

  test "destroying user destroys branding" do
    UserBranding.create!(user: @user, delivery_heading: "Test")
    branding_id = @user.user_branding.id
    @user.destroy
    assert_nil UserBranding.find_by(id: branding_id)
  end

  test "white_label defaults to false" do
    branding = UserBranding.new(user: @user)
    assert_not branding.white_label?
  end
end
