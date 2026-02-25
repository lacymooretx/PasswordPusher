# frozen_string_literal: true

require "test_helper"

class Api::V1::RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_requests = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_requests = false
  end

  test "index returns user requests" do
    get api_v1_requests_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |r| r["url_token"] == "req_abc123" }
  end

  test "show returns request details" do
    get api_v1_request_path("req_abc123", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Client Credentials", json["name"]
    assert json.key?("description") # detail mode
  end

  test "create request" do
    assert_difference("Request.count", 1) do
      post api_v1_requests_path(format: :json), params: {
        request: {name: "New API Request", description: "Test"}
      }
    end
    assert_response :created
  end

  test "update request" do
    patch api_v1_request_path("req_abc123", format: :json), params: {
      request: {description: "Updated description"}
    }
    assert_response :success
  end

  test "destroy soft-expires request" do
    delete api_v1_request_path("req_abc123", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json["expired"]
  end

  test "feature disabled returns not found" do
    Settings.enable_requests = false
    get api_v1_requests_path(format: :json)
    assert_response :not_found
  end

  test "cannot access other user requests" do
    sign_in users(:giuliana)
    get api_v1_request_path("req_abc123", format: :json)
    assert_response :not_found
  end
end
