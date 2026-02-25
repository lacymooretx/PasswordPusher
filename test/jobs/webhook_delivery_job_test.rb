# frozen_string_literal: true

require "test_helper"

class WebhookDeliveryJobTest < ActiveJob::TestCase
  setup do
    @user = users(:giuliana)
    @webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"])
  end

  test "creates delivery record on success" do
    # Stub Net::HTTP to return a successful response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "200"
    mock_response.expect :code, "200"
    mock_response.expect :code, "200"
    mock_response.expect :body, "OK"

    Net::HTTP.stub :new, ->(*_args) {
      http = Minitest::Mock.new
      http.expect :use_ssl=, nil, [true]
      http.expect :open_timeout=, nil, [10]
      http.expect :read_timeout=, nil, [15]
      http.expect :request, mock_response, [Net::HTTP::Post]
      http
    } do
      WebhookDeliveryJob.perform_now(@webhook.id, "push.viewed", {event: "push.viewed"})
    end

    delivery = @webhook.webhook_deliveries.last
    assert delivery.present?
    assert delivery.success?
    assert_equal 200, delivery.response_code
  end

  test "skips disabled webhooks" do
    @webhook.update!(enabled: false)
    assert_no_difference("WebhookDelivery.count") do
      WebhookDeliveryJob.perform_now(@webhook.id, "push.viewed", {event: "push.viewed"})
    end
  end

  test "discards job when webhook not found" do
    assert_nothing_raised do
      WebhookDeliveryJob.perform_now(-1, "push.viewed", {event: "push.viewed"})
    end
  end
end
