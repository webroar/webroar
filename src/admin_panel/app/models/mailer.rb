#--
# WebROaR - Ruby Application Server - http://webroar.in/
# Copyright (C) 2009  Goonj LLC
#
# This file is part of WebROaR.
#
# WebROaR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# WebROaR is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.
#++

unless defined?ActionMailer
  gem 'actionmailer', '2.3.9'
  require 'action_mailer'
  require 'uri'
end

class Mailer < ActionMailer::Base
  # This method is used to configure the ActionMailer::Base.smtp_settings or ActionMailer::Base.sendmail_settings
  # and returns from address ,recipients address and flags for mail_configuration status and email_notification
  # status for analytics part
  def self.mail_settings
    begin
      data = YAML::load_file(MAIL_FILE_PATH)
      mail_configuration = true
      if data['smtp']
        details = {
          :address => data['smtp']['address'],
          :port => data['smtp']['port'],
          :domain => data['smtp']['domain'],
          :authentication => data['smtp']['authentication'].to_sym,
          :user_name => data['smtp']['user_name'],
          :password => data['smtp']['password']
        }
        from = data['smtp']['from']
        recipients = data['smtp']['recipients']
        ActionMailer::Base.smtp_settings = details
      else
        details = {
          :location => data['sendmail']['location'],
          :arguments => "-i -t -f"
        }
        from = data['sendmail']['from']
        recipients = data['sendmail']['recipients']
        ActionMailer::Base.sendmail_settings = details
        ActionMailer::Base.delivery_method = :sendmail
      end
      ActionMailer::Base.raise_delivery_errors = true
    rescue
      mail_configuration = false
    end
    if data and data['email_notification'] and data['email_notification'].downcase == 'enabled'
      email_notification = true
    else
      email_notification = false
    end
    return from,recipients,mail_configuration,email_notification
  end

  # This method is to deliver the email to recipients
  def send_email(subject,body,from,recipients)
    @subject = subject
    @from = from
    @recipients = recipients
    @body = body
  end

  # This method is used to send exception notification to the recipients
  def self.send_exception(exception_hash)
    from,recipients, mail_configuration,email_notification = self.mail_settings
    if (mail_configuration and email_notification)
      subject = "#{exception_hash[:app_name]} : #{exception_hash.delete(:controller)}##{exception_hash.delete(:method)} (#{exception_hash[:exception_class]}) '#{exception_hash[:exception_message]}'"
      body = "Application Name\n.................\n#{exception_hash.delete(:app_name)}\n\n"
      body << "Error Message \n.................\n#{exception_hash.delete(:exception_message)}\n\n"
      body << "Error Class\n.............\n#{exception_hash.delete(:exception_class)}\n\n"
      body << "Time\n..................\n#{exception_hash.delete(:wall_time)}\n\n"
      body << "Backtrace \n..................\n#{exception_hash.delete(:exception_backtrace)}\n\n"
      body << "Environment\n.................\n"
      exception_hash.each do |key, value|
        body << "#{key.to_s.upcase} : #{value}\n"
      end
      begin
        deliver_send_email(subject,body,from,recipients)
      rescue Exception => e
        e
      end

    end
  end

  # This method is used to test smtp mail settings errors
  def self.check_smtp_mail_settings
    return nil if ActionMailer::Base.delivery_method == :sendmail
    from,recipients,mail_configuration,email_notification = mail_settings
    return MAIL_SETTINGS_NOT_CONFIGURED_MESSAGE,'' unless mail_configuration
    smtp_settings = ActionMailer::Base.smtp_settings if ActionMailer::Base.smtp_settings
    smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
    if smtp_settings[:enable_starttls_auto]
     smtp.enable_starttls_auto if smtp.respond_to?(:enable_starttls_auto)
    end
    begin
      smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password],smtp_settings[:authentication]) do |smtp| end;
    rescue Exception => exception
      return self.parse_exception(exception),''
    end
  end

  # this method parse the SMTP faluire exceptions
  def self.parse_exception(exception)
    case exception
    when Net::SMTPAuthenticationError
      "Authentication unsuccessful, Please make sure that email credentials are correct."
    when Net::SMTPFatalError
      "Client does not have permissions to send as this sender, Please make sure that Sender`s email address is correct."
    when Errno::ECONNREFUSED
      "Connection Refused with port #{ActionMailer::Base.smtp_settings[:port]}, Please make sure that SMTP port address is correct."
    when SocketError
      "Invalid SMTP Server, Please make sure that SMTP server address is correct."
    else
      exception.message.capitalize
    end
  end
end