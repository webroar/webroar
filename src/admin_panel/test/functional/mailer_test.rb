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
    @from,@recipients = "test@test.com","test@test.com"
  end

  # Test to send email
  def test_send_email
    print "\n Test send_email method"
    email = Mailer.deliver_send_email("Mailer Test","Test successfully completed",@from,@recipients)
    assert !ActionMailer::Base.deliveries.empty?
    assert_equal @from, email['from'].to_s
    assert_equal @recipients, email['to'].to_s
    assert_equal email.subject, "Mailer Test"
    assert_equal email.body, "Test successfully completed"
  end
end