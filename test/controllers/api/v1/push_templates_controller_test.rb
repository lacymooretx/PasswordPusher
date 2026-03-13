# frozen_string_literal: true

require "test_helper"

class Api::V1::PushTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_push_templates = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_push_templates = false
  end

  # --- index ---

  test "index returns user templates" do
    get api_v1_push_templates_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |t| t["name"] == "Quick Share" }
  end

  # --- show ---

  test "show returns template" do
    template = push_templates(:text_template)
    get api_v1_push_template_path(template, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal template.name, json["name"]
    assert_equal template.kind, json["kind"]
    assert_equal template.expire_after_days, json["expire_after_days"]
  end

  test "show returns 404 for other users template" do
    sign_in users(:giuliana)
    template = push_templates(:text_template)
    get api_v1_push_template_path(template, format: :json)
    assert_response :not_found
  end

  # --- create ---

  test "create template" do
    post api_v1_push_templates_path(format: :json), params: {
      push_template: {
        name: "API Template",
        kind: "text",
        expire_after_days: 5,
        expire_after_views: 10
      }
    }
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "API Template", json["name"]
    assert_equal "text", json["kind"]
  end

  test "create with invalid data returns errors" do
    post api_v1_push_templates_path(format: :json), params: {
      push_template: {name: "", kind: "text"}
    }
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert json.key?("errors")
  end

  test "create at max limit returns error" do
    Settings.push_templates = Config::Options.new(max_per_user: 0)
    post api_v1_push_templates_path(format: :json), params: {
      push_template: {name: "Over Limit", kind: "text"}
    }
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_match(/maximum/i, json["error"])
    Settings.push_templates = nil
  end

  # --- update ---

  test "update template" do
    template = push_templates(:text_template)
    patch api_v1_push_template_path(template, format: :json), params: {
      push_template: {name: "Updated Name"}
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["name"]
  end

  # --- destroy ---

  test "destroy template" do
    template = push_templates(:text_template)
    assert_difference("PushTemplate.count", -1) do
      delete api_v1_push_template_path(template, format: :json)
    end
    assert_response :no_content
  end

  # --- feature disabled ---

  test "feature disabled returns not found" do
    Settings.enable_push_templates = false
    get api_v1_push_templates_path(format: :json)
    assert_response :not_found
  end

  # --- unauthenticated ---

  test "unauthenticated returns unauthorized" do
    sign_out @user
    get api_v1_push_templates_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  # --- token auth ---

  test "token auth works" do
    sign_out @user
    get api_v1_push_templates_path(format: :json),
      headers: {"X-User-Email" => @user.email, "X-User-Token" => @user.authentication_token}
    assert_response :success
  end
end
