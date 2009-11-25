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

describe "HTTP" do
  it_should_behave_like "Server Setup"
  it_should_behave_like "Connection Setup"
  
  it "actual content is more than content-length should return 400 Bad Request - 1" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:4001\r\nConnection: close\r\nReferer: http://localhost:4001/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 30\r\n\r\npost_data%5Bname%5D=a&commit=Submit"
    @conn.write request
    @conn.read.should =~ /^HTTP\/1[.]1 400.*$/
  end
  
  it "actual content is more than content-length should return 400 Bad Request - 2" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:4001\r\nConnection: close\r\nReferer: http://localhost:4001/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 35\r\n\r\npost_data%5Bname%5D=a&commit=Submit"
    @conn.write request
    sleep(0.1)
    @conn.write "asdlkfjasdlkfjsadl;kfjas;ldfjk"
    @conn.read.should =~ /^HTTP\/1[.]1 (4|2)00.*$/
  end
  
  it "actual content is more than content-length should return 400 Bad Request - 3" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:4001\r\nConnection: close\r\nReferer: http://localhost:4001/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 35\r\n\r\npost_data%5Bname%5D=a&commit=Submit"
    @conn.write request
    sleep(0.1)
    @conn.write "POST kfjasdlkfjsadl;kfjas;ldfjk"
    @conn.read.should =~ /^HTTP\/1[.]1 (4|2)00.*$/
  end
  
  it "response should not have message-body when status is 304 Not Modified" do
    request = "GET /test_app/test/not_modified HTTP/1.1\r\nHost: localhost\r\n\r\n"
    @conn.write(request)
    status, headers, body  = parse_response(@conn.read)
    status.should == 304
    headers['Content-Length'].should == "0" if headers['Content-Length']
    body.should eql("")
  end
  
  it "actual content is less than content-length should return empty response" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:4001\r\nReferer: http://localhost:4001/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 35\r\n\r\npost_data%5Bnam%5D=t=Submit"
    @conn.write request
    @conn.read.should eql("")
  end
  
  #  According to http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.2
  it "response should be 400 Bad Request when host name is not given" do
    request = "GET /test_app/test/not_modified HTTP/1.1\r\n\r\n"
    @conn.write request
    @conn.read.should =~ /^HTTP\/1[.]1 400[\s\S]*The request host is missing.*/
  end
  
  #  According to http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4
  it "reqeust without 'Content-Lenght' should return 400 Bad Request" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:4001\r\nConnection: close\r\nReferer: http://localhost:4001/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\npost_data%5Bname%5D=a&commit=Submit"
    @conn.write request
    @conn.read.should =~ /^HTTP\/1[.]1 400.*$/
  end
  
end
