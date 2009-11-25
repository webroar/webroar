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

require 'spec_helper'

describe 'Heart-beat test' do
  it_should_behave_like "Server Setup"
  it_should_behave_like "Connection Setup"
  
  it "should return 500 Internal Server Error on calling stuck_worker" do
    request = "GET /test_app/test/stuck_worker HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\n\r\n"
    @conn.write request
    @conn.read.should =~ /^HTTP\/1[.]1 500.*$/
  end
  
  it "should return 200 OK on calling half_stuck_worker" do
    # Wait for new worker to get ready for service
    sleep(60)
    conn = open_connection
    request = "GET /test_app/test/half_stuck_worker HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\n\r\n"
    conn.write request
    conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    conn.close
  end
  
end
