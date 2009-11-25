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

#require 'rubygems'
#require 'action_mailer'
#$LOAD_PATH.unshift("#{File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'actionpack', 'lib')}")
#$LOAD_PATH.unshift("#{File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'actionmailer', 'lib')}")
#require File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'actionmailer', 'lib', 'action_mailer')

gem 'actionpack', '=2.3.2'
gem 'actionmailer', '=2.3.2'
require 'actionmailer' 
require 'yaml'

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
        mail_configuration=true
      else
        details ={:location=>data['sendmail']['location'],
          :arguments=>"-i -t -f"}
        from = data['sendmail']['from']
        recipients = data['sendmail']['recipients']
        ActionMailer::Base.sendmail_settings = details
        mail_configuration=true
      end
    rescue
      mail_configuration=false
      nil
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
