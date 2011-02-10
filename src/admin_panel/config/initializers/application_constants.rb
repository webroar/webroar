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

PREFIX='/admin-panel/'
if defined? RAILS_ROOT
  CONFIG_FILE_PATH="#{RAILS_ROOT}/../../conf/config.yml"
  MAIL_FILE_PATH="#{RAILS_ROOT}/../../conf/mail_config.yml"
  USERS_FILE_PATH="#{RAILS_ROOT}/config/user.yml"
end
SERVER_PORT=3000
MIN_WORKERS=4
MAX_WORKERS=8
SERVER_NAME='WebROaR' 	
LOG_LEVEL="SEVERE"	
ACCESS_LOG = "enabled"
ALLOWED_MAX_WORKERS = 20
#session timeout in minutes
SESSION_TIMEOUT = 10

MONTHS = {"January" => 1,
  "February" => 2,
  "March" => 3,
  "April" => 4,
  "May" => 5,
  "June" => 6,
  "July" => 7,
  "August" => 8,
  "September" => 9,
  "October" => 10,
  "November" => 11,
  "December" => 12}

#Messages

INVALID_DATE="Please select a valid date using the calendar."
INVALID_FROM_DATE = "Please select a valid 'From' date using the calendar."
INVALID_TO_DATE = "Please select a valid 'To' date using the calendar."
FROM_DATE_GREATERTHAN_TO_DATE = "The entered 'From Date' should be less than or equal to 'To Date'<br/>"
TO_DATE_GREATERTHAN_TODAY = "The entered 'To Date' is in future."
INVALID_HOUR = "The hour value is a numeric between 0 and 23."
BR = "<br/>"
FUTURE_DATE="The entered date/time is in future."
NO_DATA_FOUND="No data found for the selected time period ."
ADMIN_PANEL_BASE_URI="/admin-panel"
WRONG_PASSWORD1="The entered passwords does not match."
WRONG_PASSWORD2="Please enter a password with at least 6 characters."
PASSWORD_CHANGED="Password changed successfully."
WRONG_LOGIN_DETAILS="Either the user name or the password is incorrect."
USERNAME_BLANK = 'Username is blank.'
PASSWORD_BLANK = 'Password is blank.'
SUCCESSFUL_LOGOUT="Successfully logged out."
SESSION_EXPIRE_MESSAGE='Your previous login session for this application got timed out. Please login again.'
DELETE_APPLICATION_ALERT_MESSAGE="Are you sure, remove this application deployment from the server?"
RESTART_APPLICATION_ALERT_MESSAGE="Are you sure, restart this application?"
RESTART_SERVER_MESSAGE="Please restart the server to made the latest changes effective."
NO_APPLICATION_FOR_ANALYTICS="No application has been configured for analytics."
NO_APPLICATION_FOR_EXCEPTION_TRACKING="No applications are deployed on the server currently."
NO_DEPLOYED_APPLICATION_MESSAGE="No applications are deployed on the server currently."


SERVER_PORT_VALIDATION="Port should be a number between 1 and 65535."
MINIMUM_WORKERS_VALIDATION="Minimum workers should be a number between 1 and #{ALLOWED_MAX_WORKERS}."
MAXIMUM_WORKERS_VALIDATION="Maximum workers should be number between 1 and #{ALLOWED_MAX_WORKERS}."


#ApplicationSpecification Class validation message.
BASEURI_AS_ADMIN_PANEL_BASEURI_VALIDATION="'#{ADMIN_PANEL_BASE_URI}' is reserved as Admin Panel's base uri."
MIN_WORKERS_VALIDATION="Application can have utmost #{ALLOWED_MAX_WORKERS} minimum workers."
MAX_WORKERS_VALIDATION_1="Application must have maximum number of worker greater than or equal to minimum number of workers."
MAX_WORKERS_VALIDATION_2="Application can have utmost #{ALLOWED_MAX_WORKERS} maximum workers."
APPLICATION_PATH_EXISTANCE_VALIDATION="The application path entered does not exist."
ANALYTICS_VALIDATION="Analytics should be either enabled or disabled."
#ENVIRONMENT_VALIDATION="Environment should be either Production, Development or Test."
TYPE_VALIDATION="Application type should be either Rails or Rack." 
BASEURI_EXISTANCE_VALIDATION="Base URI is same as one of the previously added application."
BASEURI_AND_HOSTNAMES_EXIST = "Please correct the entered text for 'Resolver'. It cannot have both base URI (like /app1) and virtual hostname (www.company1.com) specified together."
START_WTIH_TILD = "Hostname should start with '~', as it contains wildcard '*'."
WILDCARD_AT_START_OR_END = "Hostname can only have the wildcard character either at start or at end. Please enter it again."
SUBDIVISION_EXCEEDS_127 = "Hostname subdivision can go down to maximum 127 levels."
HOSTNAME_LENGTH_EXCEEDS = "Hostname exceeds total length of 253."
HOSTNAME_LDH = "Hostname can contain only letters in upper or lower case, digits, hyphen and dot(.) to separate the labels."
LABEL_LENGTH_EXCEEDS = "Length of the label exceeds 63."
HOSTNAME_REPEATED = "Hostname is repeated."
CONSECUTIVE_DOTS = "Hostname should not have consecutive dots. Please enter it again."
APPLICATION_NAME_REPEATED = "Application name already exists. Please provide a different name."

#SSL Validations.
SSL_PORT_VALIDATION= "SSL port number should be a number between 1 and 65535."
SSL_CERTIFICATE_FILE_PATH_VALIDATION1= "Please enter complete path for the SSL certificate file."
SSL_CERTIFICATE_FILE_PATH_VALIDATION2= "Please enter the name of the certificate file with .crt extension."
SSL_CERTIFICATE_FILE_PATH_VALIDATION3= "This certificate file path does not exist."
SSL_KEY_FILE_PATH_VALIDATION1= "Please enter complete SSL key file path."
SSL_KEY_FILE_PATH_VALIDATION2= "Please enter the name of the key file with .key extension."
SSL_KEY_FILE_PATH_VALIDATION3= "This key file path does not exist."


#Graph Titles.

TOP_DATABASE_CONSUMING_URLS_GRAPH_TITLE="Top Database Consuming URLs"
PERCENTAGE_TIME_SPENT_IN_DATABASE_LAYER_GRAPH_TITLE="Percentage Time Spent in Database Layer"
CPU_USGAE_GRAPH_TITLE="Percentage CPU Utilization"
MEMORY_USAGE_GRAPH_TITLE="Physical Memory Utilization(in MB)"
AVERAGE_RESPONSE_TIME_GRAPH_TITLE="Average Response Time"
REQUEST_PER_SECOND_GRAPH_TITLE="Peak Requests Served Per Second"
URL_HITS_GRAPH_TITLE="URL Hits"
MOST_TIME_CONSUMING_GRAPH_TITLE="Most Time Consuming URLs"
SLOWEST_URLS_GRAPH_TITLE="Slowest URLs"

# SMTP validations
SMTP_ADDRESS_VALIDATION = "<li>Please enter a valid SMTP Server address.</li>"
SMTP_PORT_VALIDATION = "<li>Please enter a valid SMTP port number.</li>"
SMTP_DOMAIN_VALIDATION = "<li>Please enter a valid domain name.</li>"
SMTP_AUTHENTICATION_VALIDATION = "<li>Please enter a valid value for SMTP Authentication. It can be either of login/plain/cram-md5/ntlm-spa/digest-md5 </li>"
SMTP_USER_NAME_VALIDATION = "<li>Please enter a valid SMTP user name.</li>"
SMTP_PASSWORD_VALIDATION = "<li>Please enter a valid SMTP password.</li>"



# Sendmail validations
SENDMAIL_LOCATION_VALIDATION = "<li>Please enter a valid location for sendmail agent e.g. /usr/sbin/sendmail.</li>"
SENDMAIL_SENDER_EMAIL_VALIDATION = "<li>Please enter a valid email address of the sender.</li>"
SENDMAIL_SENDER_EMAIL_VALIDATION1 = "<li>Sender mail id is blank.</li>"
SENDMAIL_RECIPIENT_EMAIL_VALIDATION = "The following recipient email id is invalid"
SENDMAIL_RECIPIENT_EMAIL_VALIDATION1 = "<li>Recipient email id is blank.</li>"

#
RAILS = 'rails'
RACK = 'rack'

# Exception notification related
CLOSED_EXCEPTION = 0
OPEN_EXCEPTION = 1
IGNORED_EXCEPTION = 2
PERMANENTLY_IGNORED_EXCEPTION = 3

ENABLE_EMAIL_NOTIFICATION = 'Are you sure, enable email notification for the exceptions?'
DISABLE_EMAIL_NOTIFICATION = 'Are you sure, disable email notificaion for the exceptions? This would still captures exceptions and stores into database.'

EXPIRES_VALIDATION = "Possible value for expires is off or no. of seconds."
EMPTY_STRING = "Value is empty string."