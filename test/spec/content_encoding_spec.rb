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
require 'zlib'

describe 'Content-Encoding' do
  it_should_behave_like "Server Setup"
  it_should_behave_like "Connection Setup"
  
  it "should return gzip encoded content when said" do
    request = "GET /test_app/test/content_encoding HTTP/1.1\r\nHost: localhost\r\nAccept-Encoding: gzip\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response @conn.read
    io = StringIO.new(body)
    gzip = Zlib::GzipReader.new(io)
    gzip.read.should =~ /ok/
    gzip.close
  end
  
  it "should return deflate encoded content when said" do
    request = "GET /test_app/test/content_encoding HTTP/1.1\r\nHost: localhost\r\nAccept-Encoding: deflate\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response @conn.read
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    inflater.inflate(body).should =~ /ok/
    inflater.close
  end
  
  it "should return plain text when said encoding not supporting" do
    request = "GET /test_app/test/content_encoding HTTP/1.1\r\nHost: localhost\r\nAccept-Encoding: xyz\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response @conn.read
    body.should =~ /ok/
  end
  
  it "should return plain text when asked for deflate encoded content and User-Agent is MSIE 6.0" do
    request = "GET /test_app/test/content_encoding HTTP/1.1\r\nHost: localhost\r\nAccept-Encoding: deflate\r\nUser-Agent: MSIE 6.0\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response @conn.read
    body.should =~ /ok/
  end
  
  it "should return plain text when asked for gzip encoded content and User-Agent is MSIE 6.0" do
    request = "GET /test_app/test/content_encoding HTTP/1.1\r\nHost: localhost\r\nAccept-Encoding: gzip\r\nUser-Agent: MSIE 6.0\r\n\r\n"
    @conn.write request
    status, headers, body = parse_response @conn.read
    body.should =~ /ok/
  end
  
end
