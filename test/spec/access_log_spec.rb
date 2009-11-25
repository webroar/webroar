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

describe "Access-logs" do
  before(:all) do
    create_config({'access_log' => 'enabled'},{'baseuri' => '/test_app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    
    @uri = URI.parse("http://#{HOST}:#{PORT}/test_app/test/access_log")
    Net::HTTP.get(@uri)
    @size = File.size(ACCESS_LOG_FILE)
  end
  
  it "should change #{ACCESS_LOG_FILE} file size to higher value" do
    Net::HTTP.get(@uri)
    File.size(ACCESS_LOG_FILE).should > @size
  end
  
  after(:all) do
    stop_server
    remove_config.should be_true
    remove_messaging_config.should be_true
  end
  
end
