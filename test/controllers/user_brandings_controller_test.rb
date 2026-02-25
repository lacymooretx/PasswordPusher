# frozen_string_literal: true

require "test_helper"

class UserBrandingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Settings.enable_user_branding = true
  end

  teardown do
    Settings.enable_user_branding = false
  end

  test "should redirect to login when not authenticated" do
    get edit_user_branding_path
    assert_response :redirect
  end

  test "should get edit when authenticated" do
    sign_in @user
    get edit_user_branding_path
    assert_response :success
  end

  test "should update user branding" do
    sign_in @user
    patch user_branding_path, params: {
      user_branding: {
        delivery_heading: "Secure Message from Test",
        primary_color: "#336699"
      }
    }
    assert_redirected_to edit_user_branding_path

    @user.reload
    assert_equal "Secure Message from Test", @user.user_branding.delivery_heading
    assert_equal "#336699", @user.user_branding.primary_color
  end

  test "should create branding if none exists" do
    sign_in @user
    assert_nil @user.user_branding

    patch user_branding_path, params: {
      user_branding: {delivery_heading: "New Branding"}
    }
    assert_redirected_to edit_user_branding_path

    @user.reload
    assert_not_nil @user.user_branding
    assert_equal "New Branding", @user.user_branding.delivery_heading
  end

  test "should reject invalid color" do
    sign_in @user
    patch user_branding_path, params: {
      user_branding: {primary_color: "not-valid"}
    }
    assert_response :unprocessable_content
  end

  test "should redirect when feature is disabled" do
    Settings.enable_user_branding = false
    sign_in @user
    get edit_user_branding_path
    assert_response :redirect
  end
end
