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

module Webroar
  module Analyzer
    class ResourceAnalyzer

      include WithExceptionHandling
      def initialize(starling_pid)
        # @apps is a hash having application name as key and id as value. It contains all the application running under WebROaR.
        @apps = Hash.new
        # @pids is a hash having application id as key and array of pid running for a application as value.
        @pids = Hash.new
        # considering WebROaR Head, WebROaR Analyser and Starling server as a application, so that we can monitor these components in the same manner as we are monitoring rack application.
        @webroar_head = "WebROaR Head".freeze
        @webroar_analyzer = "WebROaR Analyzer".freeze
        @starling_server = "Starling Server".freeze
        load_apps
        initialize_pids(starling_pid || 0)
      end

      # Reload instance variables
      def reload_apps
        apps = nil
        with_exception_handling("App entry App.find") do
          apps = App.find(:all)
        end

        new_apps = Hash.new
        new_pids = Hash.new

        apps.each do |app|
          new_apps[app.name] = app.id
          new_pids[app.id] = @pids[app.id] || Array.new
        end

        @apps = new_apps
        @pids = new_pids

      end

      # Registering pid with given application.
      def set_pid(pid, app_name)
        WLogger.info "Got pid = #{pid} for Application = #{app_name}"
        begin

          reload_apps unless app_id = @apps[app_name]
          unless app_id = @apps[app_name]
            WLogger.error("Application #{app_name} not found.")
            return
            #TODO: Here chances of race condition in record creation with MessageAnalyzer#process_messages
          end

          @pids[app_id] <<= pid
          #WLogger.debug "After adding PID for #{app_id}, pid array is #{@pids[app_id].join(',')}"

        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          return
        end
      end

      # Determines processor usage and memory usage for the registered application.
      # Usually called at every 60 seconds.
      def take_sample
        begin
          wall_time = Time.now
          @pids.each_pair do |app_id, pid_array|
            #WLogger.debug "taking sample for app - #{app_id}, pids are #{pid_array.join(',')}"
            if pid_array.length > 0
              cmd = "ps -o pid,pcpu,rss -p #{pid_array.join(' ')}"
              #WLogger.debug cmd
              result = `#{cmd}`
              #WLogger.debug result
              result = result.split(" ")
              #WLogger.debug result
              interval = 3
              pid = Array.new
              pcpu = Array.new
              mem = Array.new
              i = 3
              while i < result.length
                if i%interval == 0
                  pid <<= result[i]
                elsif i%interval == 1
                  pcpu <<= result[i]
                elsif i%interval == 2
                  mem <<= result[i]
                end # if
                i += 1
              end # while
              pid.collect!{ |e| e.to_i }
              pcpu.collect!{ |e| e.to_f }
              mem.collect!{ |e| e.to_i}
              # In dynamic load balancing some processors might been killed. And ps command returns output for live process only.
              # By applying *and* operation of set theory, it keeps only running process id in array.
              #WLogger.debug "Before anding app_id is #{app_id}, pids array is #{@pids[app_id].join(',')}"
              @pids[app_id] &= pid
              #WLogger.debug "After anding app_id is #{app_id}, pids array is #{@pids[app_id].join(',')}"
              sum_pcpu = 0
              pcpu.each { |e| sum_pcpu += e}
              sum_mem = 0
              mem.each { |e| sum_mem += e}
              # Storing wall_time taken before the begining of block, due to that there is slight difference in actual wall_time vs resouce usage
              with_exception_handling("Resource usage entry creation for app_id=#{app_id}") do
                ResourceUsage.create({:app_id => app_id, :cpu_usage => sum_pcpu, :memory_usage => sum_mem, :wall_time => wall_time})
              end
            end # if
          end #  do |app_id, pid_array|
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          return
        end
      end  # def take_sample

      private

      def load_apps
        apps = nil
        with_exception_handling("App entry App.find") do
          apps = App.find(:all)
        end

        apps.each do |app|
          @apps[app.name] = app.id
          @pids[app.id] = Array.new
        end

      end

      def initialize_pids(starling_pid)
        begin
          @pids[@apps[@webroar_analyzer]] <<= Process.pid
          @pids[@apps[@starling_server]] <<= starling_pid.to_i

          grep_str_head = 'webroar-head'
          cmd = "ps -e -opid,comm | grep #{grep_str_head} | tail -1"
          pid = `#{cmd}`.split(' ')[0]
          @pids[@apps[@webroar_head]] <<= pid.to_i if pid
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          raise
        end
      end
    end # class ResourceAnalyzer
  end #module Analyzer
end # module Webroar
