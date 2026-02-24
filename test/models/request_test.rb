# frozen_string_literal: true

require "test_helper"

class RequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "creates with valid attributes" do
    req = Request.new(user: @user, name: "Test Request")
    assert req.save
    assert req.url_token.present?
  end

  test "requires name" do
    req = Request.new(user: @user)
    assert_not req.valid?
    assert req.errors[:name].any?
  end

  test "generates url_token on create" do
    req = Request.create!(user: @user, name: "Token Test")
    assert req.url_token.present?
    assert req.url_token.length > 10
  end

  test "active? returns true for new request" do
    req = Request.create!(user: @user, name: "Active Test")
    assert req.active?
  end

  test "active? returns false when expired" do
    req = requests(:expired_request)
    assert_not req.active?
  end

  test "active? returns false when past expiration" do
    req = Request.create!(user: @user, name: "Expired", expire_after_days: 1)
    travel 2.days
    assert_not req.active?
  end

  test "active? returns false when submissions exhausted" do
    req = Request.create!(user: @user, name: "Limited", max_submissions: 1)
    req.record_submission!
    assert_not req.active?
  end

  test "record_submission! increments count" do
    req = Request.create!(user: @user, name: "Count Test")
    assert_equal 0, req.submission_count
    req.record_submission!
    assert_equal 1, req.reload.submission_count
  end

  test "set_expiration calculates expires_at" do
    req = Request.create!(user: @user, name: "Expiry Test", expire_after_days: 7)
    assert req.expires_at.present?
    assert req.expires_at > 6.days.from_now
  end

  test "user has_many requests" do
    assert @user.respond_to?(:requests)
  end

  test "to_param returns url_token" do
    req = requests(:one_request)
    assert_equal "req_abc123", req.to_param
  end
end
