# frozen_string_literal: true

class RequestMailer < ApplicationMailer
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
