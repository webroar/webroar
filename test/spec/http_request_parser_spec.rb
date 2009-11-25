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
require 'upload_helper'

# Few tests are based on Mongrel and Thin
# TODO:
# HEAD request
# 100 Response status
# Read HTTP spec and find out all vulnerabilities.
#

describe "HTTP request parser" do
  it_should_behave_like "Server Setup"
  it_should_behave_like "Connection Setup"
  
  it "should accept chunked request path and chunked request headers" do
    request = "GET /test_app/test/chunked_header HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    request.each_char do |c|
      @conn.write c
      #      sleep(0.5)
    end
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept complete request path and complete request headers" do
    request = "GET /test_app/test/chunked_header HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept chunked request path, chunked query string and chunked request headers" do
    request = "GET /test_app/test/query_string?foo=bar&zig=zag HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    request.each_char do |c|
      @conn.write c
      #sleep(0.5)
    end
    #sleep(2)
    @conn.read.should =~ /200.*/
  end
  
  it "should accept complete request path, query string and request headers" do
    request = "GET /test_app/test/query_string?foo=bar&zig=zag HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /200.*/
  end
  
  it "should handle empty query string" do
    request = "GET /test_app/test/query_string? HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /404.*/
  end
  
  it "should handle multiple query string" do
    request = "GET /test_app/test/query_string?foo=bar&zig=zag?tip=top&ding=dong HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /200.*/
  end
  
  it "should accept chunked request path, chunked request fragment and chunked request headers" do
    request = "GET /test_app/test/chunked_header#fragment-1 HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    request.each_char do |c|
      @conn.write c
      #      sleep(0.5)
    end
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept complete request path, request fragment and request headers" do
    request = "GET /test_app/test/chunked_header#fragment-1 HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept chunked request path, chunked query string, chunked request fragment and chunked request headers" do
    request = "GET /test_app/test/query_string?foo=bar&zig=zag#fragment-1 HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    request.each_char do |c|
      @conn.write c
      #      sleep(0.5)
    end
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept complete request path, query string, request fragment and request headers" do
    request = "GET /test_app/test/query_string?foo=bar&zig=zag#fragment-1 HTTP/1.1\r\nHost: localhost\r\nCache-Control: no-transform\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should accept tiny request and return 404" do
    request = "GET / HTTP/1.1\r\nHost: test\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 404.*$/
  end
  
  it "should parse dumb headers and return 404" do
    request = "GET / HTTP/1.1\r\nHost: test\r\naaaaaaaaaaaaa:++++++++++\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 404.*$/
  end
  
  it "should return empty string as parser would get error and closes the connection-checking nasty headers" do
    request = "GET / HTTP/1.1\r\nX-SSL-Bullshit:   -----BEGIN CERTIFICATE-----\r\n\tMIIFbTCCBFWgAwIBAgICH4cwDQYJKoZIhvcNAQEFBQAwcDELMAkGA1UEBhMCVUsx\r\n\tETAPBgNVBAoTCGVTY2llbmNlMRIwEAYDVQQLEwlBdXRob3JpdHkxCzAJBgNVBAMT\r\n\tAkNBMS0wKwYJKoZIhvcNAQkBFh5jYS1vcGVyYXRvckBncmlkLXN1cHBvcnQuYWMu\r\n\tdWswHhcNMDYwNzI3MTQxMzI4WhcNMDcwNzI3MTQxMzI4WjBbMQswCQYDVQQGEwJV\r\n\tSzERMA8GA1UEChMIZVNjaWVuY2UxEzARBgNVBAsTCk1hbmNoZXN0ZXIxCzAJBgNV\r\n\tBAcTmrsogriqMWLAk1DMRcwFQYDVQQDEw5taWNoYWVsIHBhcmQYJKoZIhvcNAQEB\r\n\tBQADggEPADCCAQoCggEBANPEQBgl1IaKdSS1TbhF3hEXSl72G9J+WC/1R64fAcEF\r\n\tW51rEyFYiIeZGx/BVzwXbeBoNUK41OK65sxGuflMo5gLflbwJtHBRIEKAfVVp3YR\r\n\tgW7cMA/s/XKgL1GEC7rQw8lIZT8RApukCGqOVHSi/F1SiFlPDxuDfmdiNzL31+sL\r\n\t0iwHDdNkGjy5pyBSB8Y79dsSJtCW/iaLB0/n8Sj7HgvvZJ7x0fr+RQjYOUUfrePP\r\n\tu2MSpFyf+9BbC/aXgaZuiCvSR+8Snv3xApQY+fULK/xY8h8Ua51iXoQ5jrgu2SqR\r\n\twgA7BUi3G8LFzMBl8FRCDYGUDy7M6QaHXx1ZWIPWNKsCAwEAAaOCAiQwggIgMAwG\r\n\tA1UdEwEB/wQCMAAwEQYJYIZIAYb4QgEBBAQDAgWgMA4GA1UdDwEB/wQEAwID6DAs\r\n\tBglghkgBhvhCAQ0EHxYdVUsgZS1TY2llbmNlIFVzZXIgQ2VydGlmaWNhdGUwHQYD\r\n\tVR0OBBYEFDTt/sf9PeMaZDHkUIldrDYMNTBZMIGaBgNVHSMEgZIwgY+AFAI4qxGj\r\n\tloCLDdMVKwiljjDastqooXSkcjBwMQswCQYDVQQGEwJVSzERMA8GA1UEChMIZVNj\r\n\taWVuY2UxEjAQBgNVBAsTCUF1dGhvcml0eTELMAkGA1UEAxMCQ0ExLTArBgkqhkiG\r\n\t9w0BCQEWHmNhLW9wZXJhdG9yQGdyaWQtc3VwcG9ydC5hYy51a4IBADApBgNVHRIE\r\n\tIjAggR5jYS1vcGVyYXRvckBncmlkLXN1cHBvcnQuYWMudWswGQYDVR0gBBIwEDAO\r\n\tBgwrBgEEAdkvAQEBAQYwPQYJYIZIAYb4QgEEBDAWLmh0dHA6Ly9jYS5ncmlkLXN1\r\n\tcHBvcnQuYWMudmT4sopwqlBWsvcHViL2NybC9jYWNybC5jcmwwPQYJYIZIAYb4QgEDBDAWLmh0\r\n\tdHA6Ly9jYS5ncmlkLXN1cHBvcnQuYWMudWsvcHViL2NybC9jYWNybC5jcmwwPwYD\r\n\tVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NhLmdyaWQt5hYy51ay9wdWIv\r\n\tY3JsL2NhY3JsLmNybDANBgkqhkiG9w0BAQUFAAOCAQEAS/U4iiooBENGW/Hwmmd3\r\n\tXCy6Zrt08YjKCzGNjorT98g8uGsqYjSxv/hmi0qlnlHs+k/3Iobc3LjS5AMYr5L8\r\n\tUO7OSkgFFlLHQyC9JzPfmLCAugvzEbyv4Olnsr8hbxF1MbKZoQxUZtMVu29wjfXk\r\n\thTeApBv7eaKCWpSp7MCbvgzm74izKhu3vlDk9w6qVrxePfGgpKPqfHiOoGhFnbTK\r\n\twTC6o2xq5y0qZ03JonF7OJspEd3I5zKY3E+ov7/ZhW6DqT8UFvsAdjvQbXyhV8Eu\r\n\tYhixw1aKEPzNjNowuIseVogKOLXxWI5vAi5HgXdS0/ES5gDGsABo4fqovUKlgop3\r\n\tRA==\r\n\t-----END CERTIFICATE-----\r\n\r\n"
    begin
      @conn.write request
      #      @conn.read.should be_empty
      @conn.read.should =~ /^HTTP\/1[.]1 400.*$/
    rescue Errno::ECONNRESET, Errno::EPIPE
    end
  end
  
  it "should create parser error - checking invalid HTTP request" do
    request = "GET / SsUTF/1.1"
    @conn.write request
    #sleep(2)
    begin
      #      @conn.read.should be_empty
      @conn.read.should =~ /^HTTP\/1[.]1 400.*$/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
    end
  end
  
  it "should close the connection for incomplete requests" do
    request = "GET / HTTP/1.1\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should be_empty
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError    
    ensure
      conn.close
    end
    request = "GET /test_app/test/chunked_header HTTP/1.1\r\nHost: localhost"
    conn = open_connection
    begin
      conn.write request
      conn.read.should be_empty
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError

    ensure
      conn.close
    end
  end

  it "should fail request URI validation - 414 Request-URI Too Large" do
    request = "GET http://#{rand_data(12*1024,13*1024)}.com/#{rand_data(10,1024)} HTTP/1.1\r\nX-Test: abc\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 414[\s\S]*The request URI is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
    
    ensure
      conn.close
    end
  end

  it "should fail request path validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(1024,2048)} HTTP/1.1\r\nX-Test: abc\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The request path is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
    
    ensure
      conn.close
    end
  end

  it "should fail request fragment validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)}\##{rand_data(1024,2048)} HTTP/1.1\r\nX-Test: abc\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The request fragment is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should fail request query string validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)}?#{rand_data(10240,1024*11)} HTTP/1.1\r\nX-Test: abc\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The request query string is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should fail request field name validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)} HTTP/1.1\r\nX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-TestX-Tes: abc\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The request field name is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should fail request field value validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)} HTTP/1.1\r\nX-Test: #{rand_data(1024*80,1024*81)}\r\n\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The request field value is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should fail request header length validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)} HTTP/1.1\r\n"
    request << "#{rand_data(512,1024)}: #{rand_data(512,1024)}\r\n" * (80+32)
    request << "\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 (413|400)[\s\S]*(The request header is too large|Bad Request).*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should fail request header number validation - 413 Request Entity Too Large" do
    request = "GET /#{rand_data(10,100)} HTTP/1.1\r\n"
    request << "X-Test: abc\r\n" * 41
    request << "\r\n"
    conn = open_connection
    begin
      conn.write request
      conn.read.should =~ /^HTTP\/1[.]1 413[\s\S]*The number of request header is too large.*/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
      
    ensure
      conn.close
    end
  end
  
  it "should create parser error - checking horrible queries" do
    
    #then that large header names are caught
    10.times do |c|
      request = "GET /#{rand_data(10,120)} HTTP/1.1\r\nX-#{rand_data(1024, 1024+(c*1024))}: Test\r\n\r\n"
      conn = open_connection
      begin
        conn.write request
        #sleep(2)
        #        conn.read.should be_empty
        conn.read.should =~ /^HTTP\/1[.]1 (400|413).*$/
      rescue Errno::ECONNRESET,Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
        
      ensure
        conn.close
      end
    end
    
    #then that large mangled field values are caught
    10.times do |c|
      request = "GET /#{rand_data(10,120)} HTTP/1.1\r\nX-Test: #{rand_data(1024, 1024+(c*1024), false)}\r\n\r\n"
      conn = open_connection
      begin
        conn.write request
        #sleep(2)
        #conn.read.should be_empty
        conn.read.should =~ /^HTTP\/1[.]1 (404|413|400).*$/
      rescue Errno::ECONNRESET,Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
        
      ensure
        conn.close
      end
    end
    
    #then large headers are rejected too
    10.times do |c|
      request = "GET /#{rand_data(10,120)} HTTP/1.1\r\n"
      request << "X-Test: test\r\n" * (80 * 1024)
      request << "\r\n"
      conn = open_connection
      begin
        conn.write request
        #sleep(2)
        #      conn.read.should be_empty
        conn.read.should =~ /^HTTP\/1[.]1 413.*$/
      rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
        
      ensure
        conn.close
      end
    end
    
    #finally just that random garbage gets blocked all the time
    10.times do |c|
      request = "GET #{rand_data(1024, 1024+(c*1024), false)} #{rand_data(1024, 1024+(c*1024), false)}\r\n\r\n"
      conn = open_connection
      begin
        conn.write request
        #sleep(2)
        #        conn.read.should be_empty
        conn.read.should =~ /^HTTP\/1[.]1 (414|400).*$/
      rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
        
      ensure
        conn.close
      end
    end
    
  end
  
  it "should reject request without Request uri" do
    request = "GET  HTTP/1.1\r\n\r\n"
    @conn.write request
    #sleep(2)
    begin
      #      @conn.read.should be_empty
      @conn.read.should =~ /^HTTP\/1[.]1 400.*$/
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EINVAL, IOError
    end
  end
  
  it "should parse absolute request URI" do
    request = "GET http://localhost:4001/test_app/test/chunked_header HTTP/1.1\r\nHost: localhost:4001\r\nConnection: close\r\n\r\n"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end
  
  it "should parse post request with data" do
    request = "POST /test_app/test/post_data HTTP/1.1\r\nHost: localhost:3000\r\nCache-Control: no-transform\r\nReferer: http://localhost:3000/test_app/test/post_data\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 35\r\n\r\npost_data%5Bname%5D=a&commit=Submit"
    @conn.write request
    #sleep(2)
    @conn.read.should =~ /^HTTP\/1[.]1 200.*$/
  end

  it "should handle file uploading (Test fails if user do not have write permission on 'test_app/public' folder)" do
    create_test_file
    res = upload_file
    res.class.should == Net::HTTPOK
    remove_file
  end
end
