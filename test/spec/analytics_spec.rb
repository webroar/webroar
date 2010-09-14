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
require 'uri'
require 'time'
require File.join(WEBROAR_ROOT,'src','ruby_lib','analyzer','db_connect.rb')

describe "Analytics" do
  
  before(:all) do
    create_config({},{'baseuri' => '/test_app','analytics' => 'enabled', 'run_as_user' => 'root'}).should be_true
    create_messaging_config.should be_true
    move_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
    Webroar::Analyzer::DBConnect.establish_connection('test')
    Webroar::Analyzer::DBConnect.load_models
    
    sleep(45) # PID processor thread poll PID queue at every 30 seconds
    @t1 = Time.now - 30 #in seconds
    # To fill application profiling data
    action = 'create'
    uri = "http://#{HOST}:#{PORT}/test_app/users/"
    15.times do
      Net::HTTP.post_form(URI.parse(uri + action),{'user[name]'=>'created'})
    end
    action = 'update'
    10.times do
      Net::HTTP.post_form(URI.parse(uri + action),{'user[name]'=>'updated'})
    end
    action = 'destroy'
    10.times do
      Net::HTTP.post_form(URI.parse(uri + action),{})
    end
    
    # To check exception logging
    action='does/not/exists'
    res = Net::HTTP.post_form(URI.parse(uri + action),{})
    res = Net::HTTP.get(URI.parse(uri+action))
    
    # Wait for data to be available in DB
    sleep(120)
    @t2 = Time.now
  end
  
  it "there should be entry in resource usage for every component" do
    result_set = ResourceUsage.find(:all, :select => "app_id, sum(cpu_usage) as tot_cpu, sum(memory_usage) as tot_memory", :conditions => ["wall_time >= ? and wall_time <= ?",@t1,@t2], :group => 'app_id')
    app_ids = result_set.collect { |a| a['app_id']}
    app_ids.should_not be_empty
    # [1, 2, 3, 4, 5] for Webroar-head, Webroar-analyzer, Starling, Admin-panel, and test_app
     ([1,2,3,4,5] - app_ids).should be_empty
  end

  it "there should be correct data for application profiling" do
    result_set = AppTimeSample.find(:all, :conditions => ["wall_time >= ? and wall_time <= ?",@t1,@t2])
    result_set.should_not be_empty
    result_set.each do |result|
      result["total_time_in_request"].should >= (result["db_time"] + result["rendering_time"])
    end
    
    result_set = UrlTimeSample.find(:all, :conditions => ["wall_time >= ? and wall_time <= ?",@t1,@t2])
    result_set.should_not be_empty
    result_set.each do |result|
      result["total_time"].should >= (result["db_time"] + result["rendering_time"])
    end
    
    result_set = UrlBreakupTimeSample.find(:all, :conditions => ["wall_time >= ? and wall_time <= ?",@t1,@t2])
    result_set.should_not be_empty      
  end
  
  it "there should be exceptions captured" do
    result_set = ExceptionDetail.find(:all, :conditions => ["wall_time >= ? and wall_time <= ?",@t1,@t2])
    result_set.should_not be_empty
    post_req = result_set.select { |a| a['request_method'] == 'POST'}
    post_req.should_not be_empty
    post_req = post_req.first
    post_req['app_env'].should == 'test'
    post_req['controller'].should == 'application'
    post_req['method'].should == 'index'
    post_req.app_exception['exception_message'].should == 'No route matches "/users/does/not/exists" with {:method=>:post}'
    post_req.app_exception['exception_class'].should == 'ActionController::RoutingError'
    get_req = result_set.select { |a| a['request_method'] == 'GET'}
    get_req.should_not be_empty
    get_req = get_req.first
    get_req['app_env'].should == 'test'
    get_req['controller'].should == 'application'
    get_req['method'].should == 'index'
    get_req.app_exception['exception_message'].should == 'No route matches "/users/does/not/exists" with {:method=>:get}'
    get_req.app_exception['exception_class'].should == 'ActionController::RoutingError'
  end
  
  after(:all) do
    stop_server
    remove_config.should be_true
    remove_messaging_config.should be_true
  end

end
