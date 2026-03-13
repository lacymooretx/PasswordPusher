# frozen_string_literal: true

require "test_helper"

class PushTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_push_templates = true
    Settings.enable_logins = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_push_templates = false
  end

  # --- index ---

  test "index lists user templates" do
    get push_templates_path
    assert_response :success
    assert_match "Quick Share", response.body
  end

  test "index redirects when feature disabled" do
    Settings.enable_push_templates = false
    get push_templates_path
    assert_redirected_to root_path
  end

  test "index requires authentication" do
    sign_out @user
    get push_templates_path
    assert_redirected_to new_user_session_path
  end

  # --- new ---

  test "new renders form" do
    get new_push_template_path
    assert_response :success
    assert_match "New Push Template", response.body
  end

  test "new with kind param pre-selects kind" do
    get new_push_template_path(kind: "url")
    assert_response :success
  end

  # --- create ---

  test "create push template" do
    assert_difference("PushTemplate.count") do
      post push_templates_path, params: {
        push_template: {name: "New Template", kind: "text", expire_after_days: 3, expire_after_views: 5}
      }
    end
    assert_redirected_to push_templates_path
  end

  test "create with invalid data renders new" do
    post push_templates_path, params: {
      push_template: {name: "", kind: "text"}
    }
    assert_response :unprocessable_content
  end

  test "create at max limit shows error" do
    Settings.push_templates = Config::Options.new(max_per_user: 0)
    post push_templates_path, params: {
      push_template: {name: "Over Limit", kind: "text"}
    }
    assert_response :unprocessable_content
    Settings.push_templates = nil
  end

  # --- edit ---

  test "edit renders form" do
    template = push_templates(:text_template)
    get edit_push_template_path(template)
    assert_response :success
    assert_match "Edit Push Template", response.body
  end

  # --- update ---

  test "update push template" do
    template = push_templates(:text_template)
    patch push_template_path(template), params: {
      push_template: {name: "Renamed"}
    }
    assert_redirected_to push_templates_path
    assert_equal "Renamed", template.reload.name
  end

  test "update with invalid data renders edit" do
    template = push_templates(:text_template)
    patch push_template_path(template), params: {
      push_template: {name: ""}
    }
    assert_response :unprocessable_content
  end

  # --- destroy ---

  test "destroy push template" do
    template = push_templates(:text_template)
    assert_difference("PushTemplate.count", -1) do
      delete push_template_path(template)
    end
    assert_redirected_to push_templates_path
  end
end
