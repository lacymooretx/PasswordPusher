# frozen_string_literal: true

require "test_helper"

class Api::V1::UserBrandingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_user_branding = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_user_branding = false
  end

  test "show returns branding" do
    get api_v1_user_branding_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("brand_title")
    assert json.key?("has_logo")
  end

  test "update branding" do
    patch api_v1_user_branding_path(format: :json), params: {
      user_branding: {brand_title: "My Brand", primary_color: "#336699"}
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "My Brand", json["brand_title"]
    assert_equal "#336699", json["primary_color"]
  end

  test "update with invalid color returns error" do
    patch api_v1_user_branding_path(format: :json), params: {
      user_branding: {primary_color: "not-a-color"}
    }
    assert_response :unprocessable_content
  end

  test "feature disabled returns not found" do
    Settings.enable_user_branding = false
    get api_v1_user_branding_path(format: :json)
    assert_response :not_found
  end
end
