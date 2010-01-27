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

describe 'Host names' do
  it "should identify application" do
    create_config({},{'host_names' => 'test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test-app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
      conn.close
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should not accept _ in name" do
    create_config({},{'host_names' => 'test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test_app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 404.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should not accept .. in name" do
    create_config({},{'host_names' => 'test..app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test..app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 404.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should not accept wildcard(*) if ~ is not given in begining" do
    create_config({},{'host_names' => '*.test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: dev.test-app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 404.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should accept * in begining of name" do
    create_config({},{'host_names' => '~*.test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: dev.test-app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should accept * in end of name" do
    create_config({},{'host_names' => '~test-app.*'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test-app.com\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should not accept wildcard(*) inbetween the name" do
    create_config({},{'host_names' => '~test.*.app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test.1.app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 404.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  it "should not accept duplicate entry for host name" do
  create_config({},{'host_names' => 'test-app test-app'}).should be_true
  move_config.should be_true
  create_messaging_config.should be_true
  move_messaging_config.should be_true
  start_server.should be_true
  
  begin
    request = "GET /test/host_name HTTP/1.1\r\nHost: test.1.app\r\n\r\n"
    conn = open_connection
    conn.write request
    conn.read.should =~ /^HTTP\/1[.]1 404.*$/
  ensure
    stop_server
    remove_config.should be_true
    remove_messaging_config.should be_true
  end  
end

  # According to http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.2
  it "should identify host name from absolute-uri" do
    create_config({},{'host_names' => 'test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET http://test-app/test/host_name HTTP/1.1\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
  # According to http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.2
  it "should consider host part of absolute-uri and ignore any host header when both are given" do
    create_config({},{'host_names' => 'test-app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET http://test-app/test/host_name HTTP/1.1\r\nHost: test.1.app\r\n\r\n"
      conn = open_connection
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
  
    it "should resolve multiple host names" do
    create_config({},{'host_names' => 'test1 test2 www.test.com www.mytest.com'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    begin
      request = "GET /test/host_name HTTP/1.1\r\nHost: test1\r\n\r\n"
      conn = open_connection      
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
      request = "GET /test/host_name HTTP/1.1\r\nHost: test2\r\n\r\n"
      conn = open_connection      
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
      request = "GET /test/host_name HTTP/1.1\r\nHost: www.test.com\r\n\r\n"
      conn = open_connection      
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
      request = "GET /test/host_name HTTP/1.1\r\nHost: www.mytest.com\r\n\r\n"
      conn = open_connection      
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 200.*$/
    ensure
      stop_server
      remove_config.should be_true
      remove_messaging_config.should be_true
    end
  end
end
