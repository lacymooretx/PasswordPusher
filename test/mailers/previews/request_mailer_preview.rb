# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/request_mailer
class RequestMailerPreview < ActionMailer::Preview
  def submission_received
    request = Request.first || Request.new(
      name: "Demo Request",
      description: "Please submit your credentials",
      url_token: "preview_token",
      submission_count: 1,
      user: User.first
    )
    push = request.pushes.first || Push.first || Push.new(url_token: "preview_push")
    RequestMailer.submission_received(request, push)
  end
end
