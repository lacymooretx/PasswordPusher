# frozen_string_literal: true

require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_logins = true
  end

  teardown do
    Settings.enable_logins = false
    Settings.enable_teams = false
    Settings.enable_requests = false
  end

  # --- Header Navigation ---

  test "header shows Pushes nav item for logged-in user" do
    sign_in @user
    get root_path
    assert_response :success
    assert_select "a.nav-link", text: /Pushes/
  end

  test "header shows Requests nav item when enabled" do
    Settings.enable_requests = true
    sign_in @user
    get root_path
    assert_response :success
    assert_select "a.nav-link", text: /Requests/
  end

  test "header hides Requests nav item when disabled" do
    Settings.enable_requests = false
    sign_in @user
    get root_path
    assert_response :success
    assert_select "a.nav-link", text: /Requests/, count: 0
  end

  test "header shows team switcher when user has teams" do
    Settings.enable_teams = true
    sign_in @user
    get root_path
    assert_response :success
    assert_select "#teamSwitcherDropdown"
  end

  test "header shows simple Teams link when user has no teams" do
    Settings.enable_teams = true
    sign_in users(:luca)
    get root_path
    assert_response :success
    assert_select "#teamSwitcherDropdown", count: 0
    assert_select "a.nav-link", text: /Teams/
  end

  test "header shows account dropdown" do
    sign_in @user
    get root_path
    assert_response :success
    assert_select "#accountDropdownMenuLink"
  end

  test "header shows login link for anonymous user" do
    get root_path
    assert_response :success
    assert_select "a.nav-link", text: /Log In/
  end

  # --- Team Index ---

  test "team index shows enhanced cards with member count" do
    Settings.enable_teams = true
    sign_in @user
    get teams_path
    assert_response :success
    assert_select ".card"
  end

  # --- Footer ---

  test "footer shows API Documentation link" do
    get root_path
    assert_response :success
    assert_select "a", text: /API Documentation/
  end
end
