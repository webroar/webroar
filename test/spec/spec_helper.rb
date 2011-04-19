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

require 'rubygems'
require 'spec'
require 'net/http'
require 'uri'
require 'socket'
require 'yaml'
require 'fileutils'
require 'digest/sha1'
require 'jcode' if RUBY_VERSION.gsub(/\D/,'').to_i < 187


SPEC_DIR = File.expand_path(File.dirname(__FILE__)) unless defined? SPEC_DIR
WEBROAR_ROOT = File.expand_path(File.join(SPEC_DIR,'..','..')) unless defined? WEBROAR_ROOT
RAILS_ROOT = ADMIN_PANEL_DIR = File.join(WEBROAR_ROOT,'src','admin_panel') unless defined? ADMIN_PANEL_DIR
ALLOWED_MAX_WORKERS = 20
conf = YAML::load(File.read(File.join(WEBROAR_ROOT, 'conf', 'test_suite_config.yml')))['test_app_configuration']
HOST = 'localhost'
PORT = conf['port']
RUN_AS_USER = conf['run_as_user']
APP_NAME = 'test_app'
TEST_APP_PATH = File.join(WEBROAR_ROOT, 'test', 'spec', APP_NAME)
CONF_FILE = File.join(SPEC_DIR,'config.yml')
MESSAGING_CONF_FILE = File.join(SPEC_DIR,'server_internal_config.yml')
MAIN_CONF_FILE = File.join(WEBROAR_ROOT,'conf','config.yml')
MAIN_MESSAGING_CONF_FILE = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
ACCESS_LOG_FILE = File.join('', 'var', 'log', 'webroar', 'access.log')
TEST_RESULT = File.join(SPEC_DIR,'test.log')
TEST_SETUP_LOG = File.join(SPEC_DIR, 'setup.log')
TEST_RUN_LOG = File.join(SPEC_DIR, 'test-run.log')

def test_setup(debug_build = false)
  Dir.chdir(SPEC_DIR)
  File.truncate(TEST_SETUP_LOG,0) if File.exists?(TEST_SETUP_LOG)
  File.truncate(TEST_RESULT,0) if File.exists?(TEST_RESULT)
  File.truncate(TEST_RUN_LOG,0) if File.exists?(TEST_RUN_LOG)
  
  if debug_build
    print "Building executables ... "
    Dir.chdir(WEBROAR_ROOT)
    system("echo 'debug_build' >>#{TEST_SETUP_LOG}")
    system("rake clobber>>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
    system("rake debug_build>>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
    puts "Done"
  end
  
  if !File.exists?(File.join(WEBROAR_ROOT, 'bin' ,'webroar-head')) or !File.exists?(File.join(WEBROAR_ROOT, 'bin','webroar-worker'))
    print "Building executables ... "
    Dir.chdir(WEBROAR_ROOT)
    system("rake clobber>>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
    system("rake >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
    puts "Done"
  end
  
  Dir.chdir(SPEC_DIR)
  unless File.exists?(File.join(TEST_APP_PATH,'vendor','rails'))
    print "Creating link to admin_panel/vendor/rails ... "
    target = File.expand_path(File.join(WEBROAR_ROOT,'src','admin_panel','vendor','rails'))
    link_dir = File.expand_path(File.join(TEST_APP_PATH,'vendor'))
    system("ln -s #{target} #{link_dir} >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
    puts "Done"
  end
  
  print "Setting up Admin-panel test database ... "
  Dir.chdir(File.join(WEBROAR_ROOT,'src','admin_panel'))
  system("rake db:drop RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  system("rake db:create RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  system("rake db:migrate RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  puts "Done"
  
  print "Setting up test_app test database ... "
  Dir.chdir(TEST_APP_PATH)
  system("rake db:drop RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  system("rake db:create RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  system("rake db:migrate RAILS_ENV=test >>#{TEST_SETUP_LOG} 2>>#{TEST_SETUP_LOG}")
  system("chown #{RUN_AS_USER} db/test.sqlite3")
  if $? == 0
    puts "Done"
  else
    puts "Failed."
    puts " * Please make sure you have made relavent changes in conf/test_suite_config.yml * "
    return -1
  end
  
  Dir.chdir(SPEC_DIR)
end

def create_test_app
  App.create({:name => APP_NAME})
  true
end

def create_config(server_conf = {}, app_conf = {})
  s = {'port' => PORT, 'min_worker' => 1, 'max_worker' => 2, 'log_level' => "SEVERE"}.update(server_conf)
  a = Array.new
  a[0] = {'name'=>APP_NAME,
        'path'=>TEST_APP_PATH,
        'run_as_user'=>RUN_AS_USER,
        'type'=>'rails',
        'analytics'=> 'disabled',
        'environment'=>'test',
        'min_worker'=>1,
        'max_worker'=>2}.update(app_conf)
  
  yaml_obj=YAML::dump({'Server Specification' => s,
                        'Application Specification' => a })
  file = File.open(CONF_FILE,"w")
  file.puts yaml_obj
  file.close
  true
end

def create_messaging_config
  s = {'host' => '127.0.0.1', 'port' => '22122', 'profiler_queue_name' => 'profiler_queue', 'exception_queue_name'=>'exception_queue', 'pid_queue_name' => 'pid_queue', 'max_queue_items' => 1000}
  a = { 'pid_file' => '/var/run/webroar_analyzer.pid',
        'daemonize' => true,
        'log_file' => '/var/log/webroar/analyzer.log',
        'sampling_rate' => 1,
        'environment' => 'test'
  }
  yaml_obj = YAML::dump({'starling' => s, 'webroar_analyzer_script' => a})
  file = File.open(MESSAGING_CONF_FILE, "w")
  file.puts yaml_obj
  file.close
  true
end

def move_config
  if File.exists?(CONF_FILE)
    FileUtils.move(MAIN_CONF_FILE, MAIN_CONF_FILE+'.backup') if File.exists?(MAIN_CONF_FILE)
    FileUtils.copy(CONF_FILE, MAIN_CONF_FILE)
    return true
  end
  return false
end

def move_messaging_config
  if File.exists?(MESSAGING_CONF_FILE)
    FileUtils.move(MAIN_MESSAGING_CONF_FILE, MAIN_MESSAGING_CONF_FILE+'.backup')
    FileUtils.copy(MESSAGING_CONF_FILE, MAIN_MESSAGING_CONF_FILE)
    return true
  end
  return false
end

def remove_config
  begin
    File.delete(CONF_FILE)
  rescue Exception => e
    puts e
    puts e.backtrace
  end
  FileUtils.move(MAIN_CONF_FILE+'.backup', MAIN_CONF_FILE) if File.exists?(MAIN_CONF_FILE+'.backup')
  true
end

def remove_messaging_config
  begin
    File.delete(MESSAGING_CONF_FILE)
  rescue Exception => e
    puts e
    puts e.backtrace
  end
  FileUtils.move(MAIN_MESSAGING_CONF_FILE+'.backup', MAIN_MESSAGING_CONF_FILE)
  true
end

def start_server
  cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} start"
  system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
  if $? != 0
    return false
  end
  sleep(15)
  true
end

def stop_server
  cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} stop"
  system("#{cmd} >>#{TEST_RUN_LOG} 2>>#{TEST_RUN_LOG}")
end

def open_connection
  conn = TCPSocket.new(HOST,PORT)
end

def write_data(connection, data)
  connection.write(data)
end

def read_data(connection,bytes)
  connection.read
end

# Mongrel's lame random garbage maker
def rand_data(min, max, readable=true)
  count = min + ((rand(max)+1) *10).to_i
  res = count.to_s + "/"
  
  if readable
    res << Digest::SHA1.hexdigest(rand(count * 100).to_s) * (count / 40)
  else
    res << Digest::SHA1.digest(rand(count * 100).to_s) * (count / 20)
  end
  
  return res
end

# Thin's on the fly response parser
def parse_response(response)
  raw_headers, body = response.split("\r\n\r\n", 2)
  raw_status, raw_headers = raw_headers.split("\r\n", 2)
  
  status  = raw_status.match(%r{\AHTTP/1.1\s+(\d+)\b}).captures.first.to_i
  headers = Hash[ *raw_headers.split("\r\n").map { |h| h.split(/:\s+/, 2) }.flatten ]
  
  [ status, headers, body ]
end

shared_examples_for "Server Setup" do
  before(:all) do
    create_config({},{'baseuri' => '/test_app'}).should be_true
    move_config.should be_true
    create_messaging_config.should be_true
    move_messaging_config.should be_true
    start_server.should be_true
  end
  
  after(:all) do
    stop_server
    remove_config.should be_true
    remove_messaging_config.should be_true
  end
end

shared_examples_for "Connection Setup" do
  before(:each) do
    @conn = open_connection
  end
  
  after(:each) do
    @conn.close
  end
end
