# frozen_string_literal: true

require "test_helper"

class RequestSubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @request_obj = requests(:one_request)
    Settings.enable_requests = true
  end

  teardown do
    Settings.enable_requests = false
  end

  test "show displays public intake form" do
    get request_submission_path(@request_obj)
    assert_response :success
  end

  test "create submits text content" do
    assert_difference "Push.count", 1 do
      post request_submission_path(@request_obj), params: {
        payload: "secret_password_123"
      }
    end
    assert_response :success # renders thank_you
    assert_equal 1, @request_obj.reload.submission_count
  end

  test "expired request shows expired page" do
    expired = requests(:expired_request)
    get request_submission_path(expired)
    assert_response :success # renders expired template
  end

  test "redirects when feature disabled" do
    Settings.enable_requests = false
    get request_submission_path(@request_obj)
    assert_response :redirect
  end
end
