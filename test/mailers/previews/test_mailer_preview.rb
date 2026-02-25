# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/test_mailer
class TestMailerPreview < ActionMailer::Preview
  def send_test_email
    TestMailer.send_test_email("preview@example.com")
  end
end
