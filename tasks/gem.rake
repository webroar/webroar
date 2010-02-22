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

###############################################################################
#  Rake file for Gem packaging
###############################################################################
require 'rubygems'
#Gem::manage_gems
require 'rake/gempackagetask'

TESTFILE = "/etc/profile"
MESSAGE_DEPLOYMENT = "This command needs to be run as root. Please try again using 'sudo'.".freeze

task :clean => :clobber_package
task :package => :clean_db_log
task :gem => :clean_db_log

spec = Gem::Specification.new do |s|
  s.name                  = "webroar"
  s.version               = Webroar::VERSION::STRING
  s.platform              = Gem::Platform::RUBY
  s.summary               = "A ruby application server."
  s.description           = "WebROaR is the first true application server for ruby based web applications that provides in-built support for scalable and robust deployment of multiple applications simultaneously."
  s.authors               = ["Aditya Babbar", "Dharmarth Shah", "Nikunj Limbaseeya"]
  s.email                 = ["aditya.babbar@webroar.in", "dharmarth.shah@webroar.in", "nikunj.limbaseeya@webroar.in"]
  s.homepage              = "http://webroar.in"
  s.rubyforge_project     = "webroar"
  s.has_rdoc              = false
  s.executables           = ['webroar','webroar-analyzer']
  
  s.required_ruby_version = '>= 1.8.5'

  s.add_dependency 'rails', '>= 2.3.5'
  s.add_dependency 'calendar_date_select', '>= 1.15'  
  s.add_dependency 'rack', '>= 1.0.1'
  s.add_dependency 'rake', '>= 0.8.1'  
  s.add_dependency 'rspec', '>=1.2.2'
  s.add_dependency 'sqlite3-ruby', '>=1.2.3'
  s.add_dependency 'starling', '>=0.10.0'
  s.add_dependency 'will_paginate', '~>2.3.12'
  
  s.files = FileList['Rakefile',
    'README',
    'CHANGELOG',
    'COPYING',
    File.join('bin', 'webroar'),
    File.join('bin', 'webroar-analyzer'),
    File.join('conf', '*.yml'),
    File.join('doc', '**','*.{txt,html,png}'),
    File.join('{src,lib,tasks}', '**', '**', '*'),
    File.join('src', 'admin_panel', 'lib', 'tasks'),
    File.join('src', 'admin_panel', 'test', 'integration','*'),
    File.join('src', 'admin_panel', 'tmp','*'),
    File.join('src', 'admin_panel', 'tmp', 'cache','*'),
    File.join('src', 'admin_panel', 'tmp', 'pids','*'),
    File.join('src', 'admin_panel', 'tmp', 'sessions','*'),
    File.join('src', 'admin_panel', 'tmp', 'sockets','*')].exclude(
                                                                    File.join('src', 'admin_panel', 'db','*.*'),
                                                                    File.join('src', 'admin_panel', 'log','*.*'),
                                                                    File.join('src', 'admin_panel', 'config','user.yml'),
                                                                    File.join('src', 'admin_panel', 'test.log'),
                                                                    File.join('src', 'admin_panel', 'test_summary'),
                                                                    File.join('conf','mail_config.yml'),
                                                                    File.join('conf', 'config.yml'))
    
    s.test_files = FileList[File.join('test', '**', '*.{c,h,yml,rb,js,css,html,txt}'),
    File.join('test', 'spec','test_app','app','**','*'),
    File.join('test', 'spec','test_app','script','**','*'),
    File.join('test', 'spec', 'test_app', 'vendor', '.placeholder'),
    File.join('test', 'spec', 'test_app', 'Rakefile')].exclude(
                                                                File.join('test', 'spec', 'test_app', 'test', '**', '*'),
                                                                File.join('test', 'spec', 'test_app', 'db', 'schema.rb'))
  
  s.require_path          = "lib"
  s.bindir                = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
end

task :tag do
  sh "git tag -m 'Tagging #{Webroar::SERVER}' -a v#{Webroar::VERSION::STRING}"
end

desc "Check for root user"
task :check_root_user do
  if !File.writable?(TESTFILE)
      puts "#{MESSAGE_DEPLOYMENT}"
      return false
    end
end

desc "Install WebROaR from repository. Optionally ssl=yes(for SSL build) and debug_build=yes(for debug build) can be passed."
task :install => [:check_root_user, :clobber, :gem] do
  sh "gem install pkg/#{spec.full_name}.gem"
  opt_str = ""
  
  opt_str += "-s " if ENV["ssl"] == "yes"
  opt_str += "-d " if ENV['debug_build'] == 'yes'
  opt_str += "-i " if ENV['import'] == 'yes'
  opt_str += "--no-import " if ENV['import'] == 'no'
  opt_str += "-p#{ENV['password']} " if ENV['password']
  opt_str += "-u#{ENV['username']} " if ENV['username']
  opt_str += "-P#{ENV['port']} " if ENV['port']
  
  sh "webroar install #{opt_str}" 
end

desc "Uninstall WebROaR"
task :uninstall => :clean do
  sh "webroar uninstall"
  sh "gem uninstall -v #{Webroar::VERSION::STRING} -x webroar"
end

task :clean_db_log do
  cur_dir = File.expand_path(Dir.getwd)
  Dir.chdir(File.expand_path(File.join(File.dirname(__FILE__), '..','src','admin_panel')))
  system("rake log:clear")
  Dir.chdir(cur_dir)
end
