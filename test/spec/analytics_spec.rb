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

describe "Analytics" do

  before(:all) do
    create_config({},{'baseuri' => '/test_app','analytics' => 'enabled', 'run_as_user' => 'root'}).should be_true
    Webroar::DBConnect.db_up('test')
    create_test_app.should be_true
    create_messaging_config.should be_true
    move_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true

    sleep(45) # PID processor thread poll PID queue at every 30 seconds
    @t1 = Time.now - 30 #in seconds
    # To fill application profiling data
    action = 'create'
    uri = "http://#{HOST}:#{PORT}/test_app/users/"
    15.times do |i|
      Net::HTTP.post_form(URI.parse(uri + action),{"user[name]"=>"created#{i}"})
    end
    action = 'update'
    10.times do |i|
      Net::HTTP.post_form(URI.parse(uri + action),{"id" => i + 1,"user[name]"=>"updated#{i}"})
    end
    action = 'destroy'
    10.times do |i|
      Net::HTTP.post_form(URI.parse(uri + action),{"id" => i+1})
    end

    # To check exception logging
	action = 'edit/0'
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
    test_app_id = App.find(:first, :conditions=>["name = ?", APP_NAME]).id
    # [1, 2, 3, 4, 5, 6] for Webroar-head, Webroar-analyzer, Starling, static-worker, Admin-panel, and test_app
    ([1,2,3,4,5,test_app_id] - app_ids).should be_empty
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
    post_req.app_exception['controller'].should == 'users'
    post_req.app_exception['method'].should == 'edit'
    post_req.app_exception['exception_message'].should == 'Couldn\'t find User with ID=0'
    post_req.app_exception['exception_class'].should == 'ActiveRecord::RecordNotFound'
    get_req = result_set.select { |a| a['request_method'] == 'GET'}
    get_req.should_not be_empty
    get_req = get_req.first
    get_req['app_env'].should == 'test'
    get_req.app_exception['controller'].should == 'users'
    get_req.app_exception['method'].should == 'edit'
    get_req.app_exception['exception_message'].should == 'Couldn\'t find User with ID=0'
    get_req.app_exception['exception_class'].should == 'ActiveRecord::RecordNotFound'
  end

  after(:all) do
    stop_server
    remove_config.should be_true
    remove_test_app.should be_true
    remove_messaging_config.should be_true
  end

end