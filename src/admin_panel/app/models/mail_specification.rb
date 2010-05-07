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

class MailSpecification 
  class << self
  
    def validate_sendmail_specification(sendmail)
      str = ""
      str = SENDMAIL_LOCATION_VALIDATION if sendmail[:location].strip.length < 1
      if sendmail[:from].strip.length == 0
        str += SENDMAIL_SENDER_EMAIL_VALIDATION1
      elsif !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(sendmail[:from].strip)
        str += SENDMAIL_SENDER_EMAIL_VALIDATION      
      end
  
      if sendmail[:recipients].length == 0
        str += SENDMAIL_RECIPIENT_EMAIL_VALIDATION1
      else
        flag = 0  
        str1 = "<ul>"
        recipients = sendmail[:recipients].split(",")
        recipients.each do |recipient|
          if !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(recipient.strip)
            flag = 1
            str1 += "<li>#{recipient.strip}</li>"
          end
        end
        str1 += "</ul>"
        str += "<li>#{SENDMAIL_RECIPIENT_EMAIL_VALIDATION}-#{str1}</li>" if flag == 1
      end
      return str
    end
    
    def save_sendmail_specification(sendmail)
      data = sendmail_specification_hash(sendmail) 
      data = {'sendmail' => data, 'email_notification' => 'enabled'}
      YAMLWriter.write(data, MAIL_FILE_PATH, "sendmail")
    end
    
    def sendmail_specification_hash(sendmail=nil)
      if sendmail # create Hash from passed argument
        Hash[
            'location' => sendmail[:location],
            'arguments' => "-f",
            'from' => sendmail[:from],
            'recipients' => sendmail[:recipients]
            ]
      else # render default values
        Hash[
            'location' => '',
            'from' => '',
            'recipients' => ''
            ]
      end
    end
    
    def validate_smtp_specification(smtp)
      str = ""
      str += SMTP_ADDRESS_VALIDATION if smtp[:address].strip.length < 1
      str += SMTP_PORT_VALIDATION if smtp[:port].strip.to_i < 1
      str += SMTP_DOMAIN_VALIDATION if smtp[:domain].strip.length < 1
      str += SMTP_AUTHENTICATION_VALIDATION if smtp[:authentication].strip.length < 1
      str += SMTP_USER_NAME_VALIDATION if smtp[:user_name].strip.length < 1
      str += SMTP_PASSWORD_VALIDATION if smtp[:password].length < 1
  
      if smtp[:from].strip.length == 0
        str += SENDMAIL_SENDER_EMAIL_VALIDATION1
      elsif !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(smtp[:from].strip)
        str += SENDMAIL_SENDER_EMAIL_VALIDATION
      end
    
      if smtp[:recipients].strip.length == 0
        str += SENDMAIL_RECIPIENT_EMAIL_VALIDATION1
      else
        flag = 0  
        str1 = "<ul>"
        recipients = smtp[:recipients].split(",")
        recipients.each do |recipient|
          if !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(recipient.strip)
            flag = 1
            str1 += "<li>#{recipient.strip}</li>"
          end
        end
        str1 += "</ul>"
        str += "<li>#{SENDMAIL_RECIPIENT_EMAIL_VALIDATION}-#{str1}</li>" if flag == 1    
      end
      return str
    end
    
    def save_smtp_specification(smtp)
      data = smtp_specification_hash(smtp) 
      data = {'smtp' => data, 'email_notification' => 'enabled'}
      YAMLWriter.write(data, MAIL_FILE_PATH, "smtp")
    end
    
    def smtp_specification_hash(smtp=nil)
      if smtp   # create Hash from passed argument  
        Hash[
            'address' => smtp[:address],
            'port' => smtp[:port],
            'domain' => smtp[:domain],
            'authentication' => smtp[:authentication],
            'user_name' => smtp[:user_name],
            'password' => smtp[:password],
            'from' => smtp[:from],
            'recipients' => smtp[:recipients]
            ]
      else
        Hash[
            'address' => "",
            'port' => '25',
            'domain' => "",
            'authentication' => "login",
            'user_name' => "",
            'password' => "",
            'from' => "",
            'recipients' => ""
            ]
      end
    end
    
    def update_notification_status(status)
      @notification_conf = YAML::load_file(MAIL_FILE_PATH)      
      case status
        when :enable
          @notification_conf['email_notification'] = 'enabled'
        when :disable
          @notification_conf['email_notification'] = 'disabled'          
      end      
      yaml_obj = YAML::dump(@notification_conf)
      File.open(MAIL_FILE_PATH, 'w') do |f|
        f.puts yaml_obj
      end
    end
    
  end
end
