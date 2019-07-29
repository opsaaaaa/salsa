class TestMailer < ApplicationMailer
  default from: ENV['SES_SMTP_FROM']
  layout 'mailer'

  def test_email email, subject
    @test_email = '<h1>TEST</h1>This is a test email from Salsa'.html_safe
    mail(to: email, subject: subject)
  end
end
