# frozen_string_literal: true

require "test_helper"

# Regression coverage for GH #4381.
#
# Even when anonymous push creation is allowed (allow_anonymous: true),
# creating a *file* push / uploading attachments must require authentication.
# Otherwise an unauthenticated client could create file pushes via the
# /p.json password endpoint (with a files key or kind=file) and abuse
# file storage. Anonymous *text* pushes must still be allowed.
class FilePushApiAuthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_allow_anonymous = Settings.allow_anonymous
    Settings.enable_logins = true
    Settings.enable_file_pushes = true
    Settings.allow_anonymous = true
    Rails.application.reload_routes!
    @luca = users(:luca)
    @luca.confirm
  end

  teardown do
    Settings.allow_anonymous = @original_allow_anonymous
  end

  def test_anonymous_file_push_via_password_endpoint_with_files_is_rejected
    assert_no_difference -> { Push.where(kind: "file").count } do
      post json_pushes_path(format: :json), params: {
        password: {
          payload: "Message",
          files: [fixture_file_upload("monkey.png", "image/jpeg")]
        }
      }
    end
    assert_response :unauthorized
  end

  def test_anonymous_file_push_via_password_endpoint_with_kind_is_rejected
    assert_no_difference -> { Push.where(kind: "file").count } do
      post json_pushes_path(format: :json), params: {
        password: {
          kind: "file",
          payload: "Message",
          files: [fixture_file_upload("monkey.png", "image/jpeg")]
        }
      }
    end
    assert_response :unauthorized
  end

  def test_anonymous_text_push_still_allowed
    post json_pushes_path(format: :json), params: {
      password: {payload: "Just text"}
    }
    assert_response :success

    res = JSON.parse(@response.body)
    assert res.key?("url_token")
    push = Push.find_by(url_token: res["url_token"])
    assert_equal "text", push.kind
    assert_nil push.user
  end

  def test_authenticated_file_push_via_password_endpoint_still_works
    assert_difference -> { Push.where(kind: "file").count }, 1 do
      post json_pushes_path(format: :json), params: {
        password: {
          payload: "Message",
          files: [fixture_file_upload("monkey.png", "image/jpeg")]
        }
      },
        headers: {"X-User-Email": @luca.email, "X-User-Token": @luca.authentication_token}
    end
    assert_response :success
  end
end
