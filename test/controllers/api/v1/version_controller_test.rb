# frozen_string_literal: true

require "test_helper"

class Api::V1::VersionControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def test_version_returns_ok
    get "/api/v1/version.json"
    assert_response :ok
  end

  def test_version_includes_expected_keys
    get "/api/v1/version.json"
    assert_response :ok

    res = JSON.parse(@response.body)
    assert res.key?("application_version"), "Response should include application_version"
    assert res.key?("api_version"), "Response should include api_version"
    assert res.key?("edition"), "Response should include edition"
  end

  def test_version_requires_no_auth
    # No auth headers provided; endpoint should still succeed
    get "/api/v1/version.json"
    assert_response :ok
  end
end
