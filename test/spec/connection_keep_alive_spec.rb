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

#Based on Thin's persistent_spec.rb

describe "HTTP connection keep-alive" do
  it_should_behave_like "Server Setup"
  it_should_behave_like "Connection Setup"
  
  # Verifying connection is closed? Raises Errno::ECONNRESET or Errno::EPIPE or Errno::ECONNABORTED when connection is closed
  def test_write(request)
    conn = open_connection
    conn.write(request)
    sleep(2)
    conn.read(10)
    conn.write(request);conn.write(request);conn.write(request)
    conn.close
  end
  
  it "should not assume that a persistent connection is maintained for HTTP version 1.0" do
    request = "GET /test_app/test/keep_alive HTTP/1.0\r\nHost: localhost\r\nCache-Control: no-transform\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response(@conn.read)
    headers['Connection'].should =~ /\bclose\b/i
    lambda{test_write(request)}.should raise_error
  end
  
  it "should assume that a persistent connection is maintained for HTTP version 1.0 when specified" do
    request = "GET /test_app/test/keep_alive HTTP/1.0\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: keep-alive\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response(@conn.read)
    headers['Connection'].should =~ /\bkeep-alive\b/i
    lambda{test_write(request)}.should_not raise_error
  end
  
  it "should maintain a persistent connection for HTTP/1.1 client" do
    request = "GET /test_app/test/keep_alive HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: keep-alive\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response(@conn.read)
    headers['Connection'].should =~ /\bkeep-alive\b/i
    lambda{test_write(request)}.should_not raise_error
  end
  
  it "should maintain a persistent connection for HTTP/1.1 client by default" do
    request = "GET /test_app/test/keep_alive HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response(@conn.read)
    headers['Connection'].should =~ /\bkeep-alive\b/i
    lambda{test_write(request)}.should_not raise_error
  end
  
  it "should not maintain a persistent connection for HTTP/1.1 client when Connection header include close" do
    request = "GET /test_app/test/keep_alive HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response(@conn.read)
    headers['Connection'].should =~ /\bclose\b/i
    lambda{test_write(request)}.should raise_error
  end
end
