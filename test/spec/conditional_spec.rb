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

# Based on Mongrel's test_conditional.rb

require 'spec_helper'
require 'spec/test/unit'
require 'time'

class ConditionalResponseTest < Test::Unit::TestCase
  #describe "Conditional response" do
  it_should_behave_like "Server Setup"
  
  before(:all) do
    @http = Net::HTTP.new(HOST,PORT)
    
    #get the ETag and Last-Modified headers
    @path = "/test_app/javascripts/application.js"
    res = @http.start { |http| http.get(@path) }
    #puts res
    assert_not_nil @etag = res['ETag']
    assert_not_nil @last_modified = res['Last-Modified']
    assert_not_nil @content_length = res['Content-Length']
  end
  
  it "status should be 304 Not Modified when If-None-Match is matching ETag" do
    assert_status_for_get_and_head Net::HTTPNotModified, 'If-None-Match' => @etag
  end
  
  it "status should be 304 Not Modified when If-Modified-Since is matching Last-Modified date" do
    assert_status_for_get_and_head Net::HTTPNotModified, 'If-Modified-Since' => @last_modified
  end
  
  it "status should be 304 Not Modified when If-None-Match is matching ETag and If-Modified-Since is matching Last-Modified date" do
    assert_status_for_get_and_head Net::HTTPNotModified, 'If-None-Match' => @etag, 'If-Modified-Since' => @last_modified
  end
  
  it "status should be 200 OK when If-None-Match is invalid" do
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => 'invalid'
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => 'invalid', 'If-Modified-Since' => @last_modified
  end
  
  it "status should be 200 OK when If-Modified-Since is invalid" do
    assert_status_for_get_and_head Net::HTTPOK,                           'If-Modified-Since' => 'invalid'
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => @etag, 'If-Modified-Since' => 'invalid'
  end
  
  it "status should be 304 Not Modified when If-Modified-Since is greater than the Las-Modified header, but less than the system time" do
    sleep 2
    last_modified_plus_1 = (Time.httpdate(@last_modified) + 1).httpdate
    assert_status_for_get_and_head Net::HTTPNotModified,                           'If-Modified-Since' => last_modified_plus_1
    assert_status_for_get_and_head Net::HTTPNotModified, 'If-None-Match' => @etag, 'If-Modified-Since' => last_modified_plus_1
  end
  
  it "status should be 200 OK when If-Modified-Since is less than the Last-Modified header" do
    last_modified_minus_1 = (Time.httpdate(@last_modified) - 1).httpdate
    assert_status_for_get_and_head Net::HTTPOK,                           'If-Modified-Since' => last_modified_minus_1
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => @etag, 'If-Modified-Since' => last_modified_minus_1
  end
  
  it "status should be 200 OK when If-Modified-Since is a date in the future" do
    the_future = Time.at(2**31-1).httpdate
    assert_status_for_get_and_head Net::HTTPOK,                           'If-Modified-Since' => the_future
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => @etag, 'If-Modified-Since' => the_future
  end
  
  it "status should be 200 OK when If-None-Match is a wildcard" do
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => '*'
    assert_status_for_get_and_head Net::HTTPOK, 'If-None-Match' => '*', 'If-Modified-Since' => @last_modified
  end
  private
  
  # assert the response status is correct for GET and HEAD
  def assert_status_for_get_and_head(response_class, headers = {})
      %w{ get head }.each do |method|
      res = @http.send(method, @path, headers)
      assert_kind_of response_class, res
      assert_equal @etag, res['ETag']
      case response_class.to_s
        when 'Net::HTTPNotModified' then
        assert_nil res['Last-Modified']
        assert_nil res['Content-Length']
        when 'Net::HTTPOK' then
        assert_equal @last_modified, res['Last-Modified']
        assert_equal @content_length, res['Content-Length']
      else
        fail "Incorrect response class: #{response_class}"
      end
    end
  end
end
