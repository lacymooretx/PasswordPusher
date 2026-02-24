# frozen_string_literal: true

require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @request_obj = requests(:one_request)
    Settings.enable_requests = true
  end

  teardown do
    Settings.enable_requests = false
  end

  test "index requires authentication" do
    get requests_path
    assert_response :redirect
  end

  test "index shows requests" do
    sign_in @user
    get requests_path
    assert_response :success
  end

  test "new shows form" do
    sign_in @user
    get new_request_path
    assert_response :success
  end

  test "create makes new request" do
    sign_in @user
    assert_difference "Request.count", 1 do
      post requests_path, params: {
        request: { name: "New Test Request", allow_text: true }
      }
    end
    assert_response :redirect
  end

  test "show displays request" do
    sign_in @user
    get request_path(@request_obj)
    assert_response :success
  end

  test "destroy deactivates request" do
    sign_in @user
    delete request_path(@request_obj)
    assert @request_obj.reload.expired?
  end

  test "redirects when feature disabled" do
    Settings.enable_requests = false
    sign_in @user
    get requests_path
    assert_response :redirect
  end
end
