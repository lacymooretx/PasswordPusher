# frozen_string_literal: true

require "test_helper"

class RequestMailerTest < ActionMailer::TestCase
  test "submission_received sends email to request owner" do
    request = requests(:one_request)
    push = pushes(:test_push)

    assert_emails 1 do
      RequestMailer.submission_received(request, push).deliver_now
    end
  end

  test "submission_received is addressed to the request owner" do
    request = requests(:one_request)
    push = pushes(:test_push)

    email = RequestMailer.submission_received(request, push)
    assert_equal [request.user.email], email.to
  end

  test "submission_received subject contains request name" do
    request = requests(:one_request)
    push = pushes(:test_push)

    email = RequestMailer.submission_received(request, push)
    assert_includes email.subject, request.name
  end

  test "submission_received body references the push" do
    request = requests(:one_request)
    push = pushes(:test_push)

    email = RequestMailer.submission_received(request, push)
    assert_includes email.body.to_s, request.name
  end
end
