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

require 'rubygems'
gem 'actionmailer', '2.3.9'
require 'action_mailer'
require 'yaml'
require 'uri'

module Email
  def mail_settings
    begin 
      data= YAML::load_file("#{WEBROAR_ROOT}/conf/mail_config.yml") 
      if data['smtp']
        details={:address=>data['smtp']['address'],
          :port=>data['smtp']['port'],
          :domain=>data['smtp']['domain'],
          :authentication=>data['smtp']['authentication'].to_sym,
          :user_name=>data['smtp']['user_name'],
          :password=>data['smtp']['password']}
        from = data['smtp']['from']
        recipients = data['smtp']['recipients']
        ActionMailer::Base.smtp_settings = details        
      else
        details ={:location=>data['sendmail']['location'],
          :arguments=>"-i -t -f"}
        from = data['sendmail']['from']
        recipients = data['sendmail']['recipients']
        ActionMailer::Base.sendmail_settings = details        
      end
    rescue
      mail_configuration=false
      nil
    end
    if data and data['email_notification'] and data['email_notification'].downcase == 'enabled'
      mail_configuration = true
    else
      mail_configuration = false
    end
    return from,recipients,mail_configuration
  end
  class EmailHandler < ActionMailer::Base
    def send_email(subject, body,from,recipients)
      subject    subject 
      from       from 
      recipients recipients
      body	body
    end
  end
end
