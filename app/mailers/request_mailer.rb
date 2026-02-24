# frozen_string_literal: true

# Mailer for request (intake form) notifications.
class RequestMailer < ApplicationMailer
  # Notifies the request owner that a third party has submitted a new push.
  def submission_received(request, push)
    @request = request
    @push = push
    @user = request.user

    mail(
      to: @user.email,
      subject: I18n._("New submission received: %{name}") % { name: @request.name }
    )
  end
end
