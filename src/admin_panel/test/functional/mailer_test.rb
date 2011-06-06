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

require 'test_helper'

class MailerTest < ActionController::IntegrationTest

  def setup
    @from,@recipients,@mail_configuration,@email_notification= Mailer.mail_settings
  end

  def test_mail_configuration_availability
    print "\n Test to check mail configuration availability (will fail if email configuration not found)"
    assert @mail_configuration , true
  end

  def test_mail_notification_enability
    print "\n Test to check mail notification enability (will fail if email notification is disabled ) "
    assert @email_notification , true
  end

  # Test to send email
  def test_send_email
    print "\n Test to send email if mail configuration is availbale"
    email = Mailer.deliver_send_email("Mailer Test","Test successfully completed",@from,@recipients) if @mail_configuration
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @from, email['from'].to_s
    assert_equal @recipients, email['to'].to_s
    assert_equal email.subject, "Mailer Test"
    assert_equal email.body, "Test successfully completed"
  end
end