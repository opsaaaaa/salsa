class ApplicationMailer < ActionMailer::Base
  def send_test email, subject
    @send_test = '<h1>TEST</h1>This is a test email from Salsa'
    send_email(to: email, subject: subject)
  end
end
