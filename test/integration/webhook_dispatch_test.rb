# frozen_string_literal: true

require "test_helper"

class WebhookDispatchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    Settings.enable_webhooks = true
    Settings.enable_logins = true
  end

  teardown do
    Settings.reload!
  end

  test "viewing a push enqueues webhook delivery job" do
    push = pushes(:test_push)

    assert_enqueued_with(job: WebhookDeliveryJob) do
      get "/p/#{push.url_token}.json"
    end
  end

  test "creating a push via API enqueues webhook for push.created" do
    user = users(:giuliana)
    sign_in user

    webhook = webhooks(:test_webhook)
    webhook.update!(events: ["push.viewed", "push.expired", "push.created"])

    assert_enqueued_with(job: WebhookDeliveryJob) do
      post "/p.json",
        params: {password: {payload: "test-webhook-payload"}},
        headers: {"X-User-Email" => user.email, "X-User-Token" => user.authentication_token}
    end
  end

  test "no webhook enqueued when feature is disabled" do
    Settings.enable_webhooks = false
    push = pushes(:test_push)

    assert_no_enqueued_jobs(only: WebhookDeliveryJob) do
      get "/p/#{push.url_token}.json"
    end
  end

  test "no webhook enqueued when user has no webhooks" do
    user = users(:one)
    push = Push.create!(
      kind: :text,
      payload: "test-no-webhook",
      expire_after_days: 7,
      expire_after_views: 5,
      user: user
    )

    assert_no_enqueued_jobs(only: WebhookDeliveryJob) do
      get "/p/#{push.url_token}.json"
    end
  end
end
