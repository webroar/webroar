#--
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
#++

#This is the model class ResourceUsage related to the resource_usages table in the database.
class ResourceUsage < ActiveRecord::Base
  class << self
    #This method is used to get the latest state of the server i.e. its cpu usage and physical memory usage.
    # Returns array wtih 2 element, first element is cpu usage, 2nd is memory usage in kb
    def get_latest_for_server
      t1 = Time.now
      interval = 60 # in seconds
      t2 = t1 - interval
      result = find(:first, :select => "sum(cpu_usage) as tot_cpu, sum(memory_usage) as tot_memory", :conditions => ["wall_time <= ? and wall_time >= ?",t1,t2])
      if !result
        res = [0.0, 0]
      else
        res = [result.tot_cpu.to_f, result.tot_memory.to_i]
      end
      res
    end
    
    #This method is used to get the latest state of the application i.e. its cpu usage and physical memory usage.
    # Returns hash with application name as key and 2 element array as value. In 2 element, first element is cpu usage, 2nd is memory usage in kb
    def get_latest_for_apps
      t1 = Time.now
      interval = 60 # in seconds
      t2 = t1 - interval
      result_set = find(:all, :select => "app_id, sum(cpu_usage) as tot_cpu, sum(memory_usage) as tot_memory", :conditions => ["wall_time <= ? and wall_time >= ?",t1,t2], :group => 'app_id')
      
      if result_set.length == 0
        {}
      else
        apps = App.find(:all, :select => "id, name")
        app_hash = Hash.new
        apps.each do |app|
          app_hash[app.id] = app.name
        end
        result_hash = Hash.new
        result_set.each do |result|
          result_hash[app_hash[result.app_id]] = [result.tot_cpu.to_f, result.tot_memory.to_i]
        end # do |result|
        result_hash
      end # if
    end
    
    #This method Returns the Resource Usage data for the server. This data is used to plot the graph for cpu usage and memory usage of the server.
    #CPU usage is in percentage and the physical memory usage is MBs.
    def get_server_resource_usage(start_time, end_time, type)
      max = 0
      interval = 0
      interval = ((end_time - start_time) / 60).to_i
      final_data = Array.new(interval)
      wall_time = Array.new(interval)
      resource_usages = find(:all, :select=>'wall_time, sum(cpu_usage) as cpu_usage, sum(memory_usage) as memory_usage', :conditions => ["wall_time >= ? and wall_time < ?", start_time, end_time], :group => 'wall_time')
     resource_usages.each do |resource_usage| 
          current_time = Time.local(resource_usage.wall_time.year,  resource_usage.wall_time.month, resource_usage.wall_time.day, resource_usage.wall_time.hour, resource_usage.wall_time.min, '0')
          index = (current_time - start_time) / 60
          if type == "CPU"
            total_data = resource_usage.cpu_usage
          elsif type == "Memory"
            total_data = resource_usage.memory_usage.to_f / 1024
          end
          if max < total_data
            max = total_data.to_i
          end
          final_data[index] = total_data
          wall_time[index] = current_time.strftime("%H:%M")
      end  
      for i in 0..interval
          if final_data[i].nil?
              wall_time[i] = (start_time+i*60).strftime("%H:%M")
          end
      end
      max, slab = get_max_and_slab(max)
      fill_gaps!(final_data)
      step = (interval + 1) / 20
      return wall_time, final_data, max, slab, step
    end

 
    #This method Returns the Resource Usage data for a particular application. This data is used to plot the graph for cpu usage and memory usage for that application.
    #CPU usage is in percentage and the physical memory usage is MBs.

    def get_application_data(app_id, start_time, end_time, type)
      max = 0
      interval = 0
      interval = ((end_time - start_time) / 60).to_i
      final_data = Array.new(interval)
      wall_time = Array.new(interval)
      resource_usages = find(:all, :select => 'sum(cpu_usage) as cpu_usage, sum(memory_usage) as memory_usage, count(*) as count, wall_time', :conditions => ['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'wall_time')
        resource_usages.each do |resource_usage|
            current_time = Time.local(resource_usage.wall_time.year, resource_usage.wall_time.month, resource_usage.wall_time.day, resource_usage.wall_time.hour, resource_usage.wall_time.min, '0')
            index = (current_time - start_time) / 60
            count = resource_usage.count
            if type == "cpu"
              total_data = resource_usage.cpu_usage
            elsif type == "memory"
              total_data = resource_usage.memory_usage.to_f / 1024
            end
          if max < total_data
            max = total_data.to_i
          end
          final_data[index] = total_data
          wall_time[index] = current_time.strftime("%H:%M")
        end

       for i in 0..interval
          if final_data[i].nil?
              wall_time[i] = (start_time+i*60).strftime("%H:%M")
          end
      end

      max,slab = get_max_and_slab(max)
      fill_gaps!(final_data)
      step = (interval + 1) / 20
      return wall_time, final_data, max, slab, step
    end

    #This method gives the maximum value for y axis and the value by which the y axis is to be partitioned.
    def get_max_and_slab(max)
      if max == 0
        max = 1
        slab = 1
      else
        if max > 8
          slab = max/8.to_i
        else
          slab = 1
        end
      end
      max = max.to_i + slab
      return max, slab
    end
    
    # Due to technical reasons, e.g. sleep(60) , thread can remain in sleep state for more than 60 seconds, in this case it may not get sample for that minute.
    # With this method filling any such gaps(consecutive one gap at max) by predicting usage from around values.
    # Parameters : array(Array) of integer or float
    # Find out the elements having 0 or 0.0 as value, normalize it value according to previous/next values.
    def fill_gaps!(array)
      if array.length > 0  # proceed only if array is not empty
        if array[0] == 0 # if first element is zero, predict value from next two values.
          if array.length > 2 and array[1] != 0 and array[2] != 0 and !array[1].nil? and !array[2].nil?
            array[0] = (array[1] + array[2]) / 2
          end # if array.length > 2
        end # if array[0].to_i == 0
        
        if array[-1] == 0 #if last element is zero, predict value from previous two values.
          if array.length > 2 and array[-2] != 0 and array[-3] != 0 and !array[-2].nil? and !array[-3].nil?
            array[-1] = (array[-2] + array[-3]) / 2
          end # if array.length > 2
        end # if array[-1].to_i == 0
        
        for i in 1..array.length-1 # checking for interminant values
          if array[i] == 0 and array[i-1] != 0 and array[i+1] != 0 and !array[i-1].nil? and !array[i+1].nil?
            array[i] = (array[i-1] + array[i+1]) / 2
          end # if
        end # for
      end # if array.length > 0
    end # fill_gaps
    
  end # self
end
