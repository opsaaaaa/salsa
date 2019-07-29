class ApplicationMailer < ActionMailer::Base
  default from: ENV['SES_SMTP_FROM']
  layout 'mailer'

  def send_email config
      email_override = APP_CONFIG['email_override']
  
      if email_override
        to = config[:to]
        subject = config[:subject]
        
        config[:to] = email_override
        config[:subject] = "#{to} - #{subject}"
      end
  
      mail(to: config[:to], subject: config[:subject])
    end
end
