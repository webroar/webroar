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

gem 'starling', '>=0.10.0'
require 'starling'

module Webroar
  module Analyzer
    class MessageReader
      def initialize(host, port, profiler_queue_name,exception_queue_name, pid_queue_name)
        @server = %Q{#{host}:#{port}}.freeze
        @starling = Starling.new(@server, :timeout => 30.0)
        @profiler_queue = profiler_queue_name.freeze
        @exception_queue = exception_queue_name
        @pid_queue = pid_queue_name   
        # Until an item is set into queue, stats(e.g. sizeof) of that queue is not available(after every time starling has been restarted).
        @starling.set(@profiler_queue,{}) rescue nil
        @starling.set(@exception_queue,{}) rescue nil     
        #@starling.set(@pid_queue, {}) rescue nil
      end
      
      #TODO: one read method for every queue
      def read
        begin
          if @starling.sizeof(@profiler_queue) > 0
            @starling.get(@profiler_queue)
          else
            nil
          end
        rescue MemCache::MemCacheError, Timeout::Error => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        rescue Exception => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        end
      end
      
      def read_exception
        begin
          if @starling.sizeof(@exception_queue) > 0
            return @starling.get(@exception_queue)
          else
            return nil
          end
        rescue MemCache::MemCacheError, Timeout::Error => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        rescue Exception => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        end
      end
      
      def read_pid
        begin
          if @starling.sizeof(@pid_queue) > 0
            # read raw entry
            return @starling.get(@pid_queue, true)
          else
            return nil
          end
        rescue MemCache::MemCacheError, Timeout::Error => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        rescue Exception => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          nil
        end
      end
      
    end # class MessageReader
  end # module Analyzer
end # module Webroar
