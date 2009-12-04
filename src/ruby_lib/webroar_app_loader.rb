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
begin
  require File.join(File.expand_path(File.dirname(__FILE__)), 'ruby_interface', 'ruby_interface')
  
  #turn it on to see the Ruby exception
  $DEBUG = $g_options['debug']
=begin
  $g_options = Hash.new
  $g_options["root"]="/home/dshah/work/rails_workspace/test2.3"
  #$g_options["root"]="/home/dharmarth/work/merb_workspace/iBlogs-activerecord"
  $g_options["app_type"]="rails"
  $g_options["app_name"]="Planning Poker"
  $g_options["prefix"] = "/test"
  $g_options["app_profiling"]="no"
  $g_options["webroar_root"] = "/home/dshah/workspace/webroar"
=end
  
  module Webroar
    class AdapterLoader
      ADAPTER_FILES.each { |f|
        if f.include?("#{$g_options["app_type"]}.rb")
          require f
          break
        end
      }
      ADAPTER = Adapter.get($g_options["app_type"])
      $app = ADAPTER.new($g_options)
      $app = Webroar::Deflater.new($app)
      
      #left over for debugging  
      #    STDIN.reopen('/dev/null')     
      #    STDOUT.reopen("/home/dshah/workspace/webroar/webroar_prof", "a")        
      #    STDOUT.sync = true
      #    STDERR.reopen(STDOUT)
      #    STDERR.sync = true
      #    puts '...........file opened..............'
      require File.join(File.dirname(__FILE__), 'profiler', 'message_dispatcher') #to send pid of worker
      if $pid_sent
        require File.join(File.dirname(__FILE__), 'exception_tracker', 'webroar_exception.rb')
      else
        Webroar.log_info("Exception notification would not work.")
      end
      if $g_options["app_profiling"] == "yes"
        if $pid_sent
          require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'profiler', 'webroar_profiling.rb'))     
        else
          Webroar.log_info("Profiling did not started.")
        end
      end
      
      # Taken from Mongrel cgi_multipart_eof_fix
      # Ruby 1.8.5 has a security bug in cgi.rb, we need to patch it.
      version = RUBY_VERSION.split('.').map { |i| i.to_i }      
      if version[0] <= 1 && version[1] <= 8 && version[2] <= 5 && RUBY_PLATFORM !~ /java/
        begin
          require 'cgi_multipart_eof_fix'
        rescue LoadError
          Webroar.log_info "!! Ruby 1.8.5 is not secure please install cgi_multipart_eof_fix:"
          Webroar.log_info "   gem install cgi_multipart_eof_fix"
        end
      end
    end #AdapterLoader
  end #Webroar
  Webroar.log_info("Application loaded successfully")
rescue Exception => e
  error = e.to_s + "\n" + e.backtrace.join("\n").to_s
  Webroar.log_error(error)
  raise
end