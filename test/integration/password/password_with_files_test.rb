# frozen_string_literal: true

require "test_helper"

class PasswordWithFilesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @orig_enable_logins = Settings.enable_logins
    @orig_enable_file_pushes = Settings.enable_file_pushes
    @orig_allow_anonymous = Settings.allow_anonymous
    Settings.enable_logins = true
    Settings.enable_file_pushes = true
    Rails.application.reload_routes!
    @luca = users(:luca)
    @luca.confirm
    sign_in @luca
  end

  teardown do
    sign_out :user
    Settings.enable_logins = @orig_enable_logins
    Settings.enable_file_pushes = @orig_enable_file_pushes
    Settings.allow_anonymous = @orig_allow_anonymous
  end

  def test_text_push_with_file_attachment
    get new_push_path(tab: "text")
    assert_response :success

    # File upload section should be visible for logged-in users when file pushes enabled
    assert response.body.include?("Attach Files")

    post pushes_path, params: {
      push: {
        kind: "text",
        payload: "secret password here",
        files: [
          fixture_file_upload("monkey.png", "image/jpeg")
        ]
      }
    }
    assert_response :redirect

    # Preview page
    follow_redirect!
    assert_response :success
    assert_select "h2", "Push Preview"

    # Show page — should display both text and files
    get request.url.sub("/preview", "")
    assert_response :success

    # Assert the password is in the page
    pre = css_select "pre"
    assert(pre)
    assert(pre.first.content.include?("secret password here"))

    # Assert files are shown
    download_link = css_select "a.list-group-item.list-group-item-action"
    assert(download_link)
    assert(download_link.first.content.include?("monkey.png"))
  end

  def test_text_push_file_count_limit
    @old_max = Settings.files.max_file_uploads
    Settings.files.max_file_uploads = 1

    # Upload 2 files should fail
    post pushes_path, params: {
      push: {
        kind: "text",
        payload: "secret",
        files: [
          fixture_file_upload("monkey.png", "image/jpeg"),
          fixture_file_upload("test-file.txt", "text/plain")
        ]
      }
    }
    assert_response :unprocessable_content

    Settings.files.max_file_uploads = @old_max
  end

  def test_text_push_without_files_still_works
    post pushes_path, params: {
      push: {
        kind: "text",
        payload: "just a password, no files"
      }
    }
    assert_response :redirect

    follow_redirect!
    assert_response :success
    assert_select "h2", "Push Preview"
  end

  def test_file_section_hidden_when_file_pushes_disabled
    Settings.enable_file_pushes = false

    get new_push_path(tab: "text")
    assert_response :success

    assert_not response.body.include?("Attach Files")
  end

  def test_file_section_hidden_for_anonymous_users
    sign_out :user
    Settings.allow_anonymous = true

    get new_push_path(tab: "text")
    assert_response :success

    assert_not response.body.include?("Attach Files")
  end
end
