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
      def initialize(options)
        @server = %Q{#{options["host"]}:#{options["port"]}}.freeze
        @starling = Starling.new(@server, :timeout => 30.0)
        @profiler_queue = options["profiler_queue_name"].freeze
        @exception_queue = options["exception_queue_name"].freeze
        @pid_queue = options["pid_queue_name"].freeze
        # Until an item is set into queue, stats(e.g. sizeof) of that queue is not available(after every time starling has been restarted).
        @starling.set(@profiler_queue,{}) rescue nil
        @starling.set(@exception_queue,{}) rescue nil
        #@starling.set(@pid_queue, {}) rescue nil
      end

      def read_profiling_data
        read(@profiler_queue)
      end

      def read_exception
        read(@exception_queue)
      end

      def read_pid
        # read raw entry
        read(@pid_queue, true)
      end

      private

      def read(queue_name, raw = false)
        begin
          @starling.fetch(queue_name, raw)
        rescue MemCache::MemCacheError, Timeout::Error => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          nil
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          nil
        end
      end

    end # class MessageReader
  end # module Analyzer
end # module Webroar
