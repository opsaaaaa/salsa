class TestMailer < ApplicationMailer
  def test_email email, subject
    @test_email = '<h1>TEST</h1>This is a test email from Salsa'.html_safe
    send_email(to: email, subject: subject)
  end
end
