# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_logins = true
    Settings.enable_webhooks = true
    Settings.enable_requests = true
    Settings.enable_teams = true

    @giuliana = users(:giuliana)
    @one = users(:one)
    @push = pushes(:test_push) # belongs to giuliana
  end

  teardown do
    Settings.reload!
  end

  # --- Helper ---

  def api_headers(user)
    {"X-User-Email" => user.email, "X-User-Token" => user.authentication_token}
  end

  # ===================================================================
  # Push ownership: user :one cannot delete giuliana's push
  # ===================================================================

  test "user cannot delete another user's push via API" do
    # The push belongs to giuliana and has deletable_by_viewer defaulting to true,
    # so we explicitly turn it off to test ownership enforcement.
    @push.update!(deletable_by_viewer: false)

    delete "/p/#{@push.url_token}.json", headers: api_headers(@one)

    assert_response :unauthorized
    assert_not @push.reload.expired?
  end

  # ===================================================================
  # Push audit: user :one cannot view audit of giuliana's push
  # ===================================================================

  test "user cannot view audit of another user's push via API" do
    get "/p/#{@push.url_token}/audit.json", headers: api_headers(@one)

    assert_response :forbidden
    res = JSON.parse(@response.body)
    assert res.key?("error")
  end

  # ===================================================================
  # Webhook ownership: user :one cannot view giuliana's webhooks
  # ===================================================================

  test "user cannot view another user's webhook" do
    webhook = webhooks(:test_webhook) # belongs to giuliana

    sign_in @one
    get webhook_path(webhook)

    # The controller scopes to current_user.webhooks.find(params[:id])
    # which raises RecordNotFound, rescued by Rails as 404
    assert_response :not_found
  end

  test "user cannot edit another user's webhook" do
    webhook = webhooks(:test_webhook)

    sign_in @one
    get edit_webhook_path(webhook)

    assert_response :not_found
  end

  test "user cannot update another user's webhook" do
    webhook = webhooks(:test_webhook)

    sign_in @one
    patch webhook_path(webhook), params: {webhook: {url: "https://evil.com/steal"}}

    assert_response :not_found
    assert_equal "https://example.com/webhook", webhook.reload.url
  end

  test "user cannot destroy another user's webhook" do
    webhook = webhooks(:test_webhook)

    sign_in @one
    assert_no_difference("Webhook.count") do
      delete webhook_path(webhook)
    end

    assert_response :not_found
  end

  # ===================================================================
  # Request ownership: user :one cannot view/update/destroy giuliana's
  # requests (using requests created in-test for giuliana)
  # ===================================================================

  test "user cannot view another user's request" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's Secret Request",
      allow_text: true
    )

    sign_in @one
    get request_path(giuliana_request)

    # Controller uses current_user.requests.find_by! -> RecordNotFound -> 404
    assert_response :not_found
  end

  test "user cannot update another user's request" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's Secret Request",
      allow_text: true
    )

    sign_in @one
    patch request_path(giuliana_request), params: {request: {name: "Hacked"}}

    assert_response :not_found
    assert_equal "Giuliana's Secret Request", giuliana_request.reload.name
  end

  test "user cannot destroy another user's request" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's Secret Request",
      allow_text: true
    )

    sign_in @one
    delete request_path(giuliana_request)

    assert_response :not_found
    assert_not giuliana_request.reload.expired?
  end

  test "user cannot view another user's request via API" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's API Request",
      allow_text: true
    )

    get "/api/v1/requests/#{giuliana_request.url_token}.json", headers: api_headers(@one)

    assert_response :not_found
  end

  test "user cannot update another user's request via API" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's API Request",
      allow_text: true
    )

    put "/api/v1/requests/#{giuliana_request.url_token}.json",
      params: {request: {name: "Hacked via API"}},
      headers: api_headers(@one)

    assert_response :not_found
    assert_equal "Giuliana's API Request", giuliana_request.reload.name
  end

  test "user cannot destroy another user's request via API" do
    giuliana_request = Request.create!(
      user: @giuliana,
      name: "Giuliana's API Request",
      allow_text: true
    )

    delete "/api/v1/requests/#{giuliana_request.url_token}.json", headers: api_headers(@one)

    assert_response :not_found
    assert_not giuliana_request.reload.expired?
  end

  # ===================================================================
  # Team membership: non-member cannot modify team settings
  # ===================================================================

  test "non-member cannot edit team policy" do
    team = teams(:one_team) # owned by :one, giuliana is admin member
    luca = users(:luca)

    sign_in luca
    # luca is not a member of one_team, so current_user.teams.find_by!
    # raises RecordNotFound, rescued by Rails as 404
    get edit_team_policy_path(team)

    assert_response :not_found
  end

  test "non-member cannot update team policy" do
    team = teams(:one_team)
    luca = users(:luca)

    sign_in luca
    patch team_policy_path(team), params: {
      policy: {defaults: {pw: {expire_after_days: 1}}}
    }

    assert_response :not_found
  end

  test "non-member cannot update team details" do
    team = teams(:one_team)
    luca = users(:luca)
    original_name = team.name

    sign_in luca
    patch team_path(team), params: {team: {name: "Hacked Team Name"}}

    # Non-member cannot find team via current_user.teams -> 404
    assert_response :not_found
    assert_equal original_name, team.reload.name
  end

  test "non-member cannot destroy team" do
    team = teams(:one_team)
    luca = users(:luca)

    sign_in luca
    assert_no_difference("Team.count") do
      delete team_path(team)
    end

    assert_response :not_found
    assert Team.exists?(team.id)
  end
end
