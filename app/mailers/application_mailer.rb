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

      if config[:to].kind_of?(Array)
        config[:to] = config[:to].select do |email|
          # remove test emails
          email.exclude? '@example.com'
        end
      elsif config[:to].include? '@example.com'
        raise "Invalid email: #{config[:to]}"
      end
  
      mail(to: config[:to], subject: config[:subject])
    end
end
