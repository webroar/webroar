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

require 'singleton'
require 'yaml'
#$: << Bundler.bundle_path.join("gems", "starling-0.10.1", "lib")
#gem 'starling', '>=0.10.0'
#require 'starling'

module Webroar
  module Profiler
    class MessageDispatcher
      include Singleton
      #MAX_ENTRY = 30000
      def initialize
        @app_name = $g_options["app_name"].freeze
        @app_env = $g_options["environment"].freeze
        filename = File.join($g_options["webroar_root"],'conf','server_internal_config.yml')
        configuration = YAML.load(File.open(filename))["starling"]
        host = configuration["host"]
        port = configuration["port"]        
        @server = %Q{#{host}:#{port}}.freeze
        @starling = Starling.new(@server)
        @profiler_queue = "#{configuration['profiler_queue_name']}".freeze       
        @exception_queue = "#{configuration['exception_queue_name']}".freeze
        @pid_queue = "#{configuration['pid_queue_name']}".freeze
        @max_entry = configuration["max_queue_items"] || 10000
        # Until an item is set into queue, stats(e.g. sizeof) of that queue is not available(after every time starling has been restarted).
        # setting it from Analyzer process, as once the stats available with Starling server, it can reach to all the clients
        #@starling.set(@profiler_queue,{}) rescue nil
        #@starling.set(@exception_queue,{}) rescue nil
        #@starling.set(@pid_queue,{}) rescue nil
      end

      def log_spent_time(url_metric)
        #TODO: map uri metric with process id instead of app_name
        #Webroar.log_info("spent_time=#{url_metric[:controller_action][2]}")
        url_metric.merge!({:message_type => 'url_metric', :app_name => @app_name})
        send_entry(@profiler_queue, url_metric)
      end

      def send_pid()
        # It looks Starling is reading entire queue log file before the very first operation on it. It takes long time to respond to first 
        # call and IO timeout error is thrown by memcache-client.
        # http://github.com/starling/starling/issues/issue/4
        # Creating a temporary connection with higher timeout value to set PID successfully. 
        starling = Starling.new(@server, :timeout => 15.0)
        begin
          # send raw entry
          starling.set(@pid_queue, "#{@app_name}:#{Process.pid}", 0, true)
          Webroar.log_info("PID #{Process.pid} sent on queue.")
          $pid_sent = true
        rescue MemCache::MemCacheError, Timeout::Error => e
          Webroar.log_error("Dispatching message on queue:#{e}")
          Webroar.log_error("#{e.backtrace.join("\n")}")
          Webroar.log_info("Dispatching pid on queue failed.")
          $pid_sent = false
        end
      end

      def send_entry(queue, value, *args)        
        begin
          if @starling.sizeof(queue) < @max_entry
            @starling.set(queue, value, *args)
            true
          else
            Webroar.log_info("Number of messages in #{queue} has exceeds limit of #{@max_entry}. Failed to set the message.")
            false
          end
        rescue  MemCache::MemCacheError, Timeout::Error => e
          Webroar.log_error("Dispatching message on queue:#{e}")
          Webroar.log_error("#{e.backtrace.join("\n")}")
          false
        end          
      end

      def log_exception(exception_details)
        exception_details[:app_name] = @app_name
        exception_details[:app_env] = @app_env
        send_entry(@exception_queue, exception_details)
      end

    end # MessageDispatcher

    MessageDispatcher.instance.send_pid()

  end # Profiler
end # Webroar

