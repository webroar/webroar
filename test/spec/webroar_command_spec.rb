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

describe "Webroar command" do
  it_should_behave_like "Server Setup"
  
  before(:all) do
    @http = Net::HTTP.new(HOST,PORT)
  end
  
  it 'should stop test_app' do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} stop test_app"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    sleep(5)
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPNotFound
  end
  
  it 'should start test_app' do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} start test_app"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    sleep(60)
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPOK
  end
  
  it "should clear log file" do
    log_file = File.join('', 'var', 'log', 'webroar', 'webroar.log')
    File.size(log_file).should > 0
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} clear"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    File.size(log_file).should be_zero
  end
  
  it "should restart application" do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} restart test_app"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    sleep(60)
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPOK
  end
  
  it "should return version string" do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} -v"
    op = `#{cmd}`
    op.should =~ /WebROaR-\d[.]\d[.]\d/
  end
  
  it "should remove application" do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} remove test_app"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    sleep(5)
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPNotFound
  end
  
  it "should add application" do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} add test_app -R /test_app -D #{TEST_APP_PATH} -U #{RUN_AS_USER} -N 1 -X 2 -E test"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
    sleep(60)
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPOK
  end
  
  it "should respond during application restart" do
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} restart test_app"
    system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")    
    res = @http.start{ |http| http.get('/test_app/')}
    res.class.should == Net::HTTPOK
    sleep(60)
  end
end
