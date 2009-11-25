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

#This module is used to get the data for the Throughput Graphs i.e. Average response time and throughput graphs.
module Analytics
  module Throughput
    #This method is to populate the varriable avg_res_time_graph and app_throughput_graph with the respective graphs data.
    #avg_res_time_graph contains the data for average response time for an application.
    #app_throughput_graph contains the data for throughput of an application .
    def get_throughput_graph(app_id)
      @start_hour, @end_hour, start_time, end_time = get_start_and_end_time_from_session()      
      avg_res_time_graph = plot_graph("graph/get_average_response_data/#{app_id}?time_slab=#{start_time}.#{end_time}",'average_response')#Graph depicts the average response time of application
      app_throughput_graph = plot_graph("graph/get_peak_requests_data/#{app_id}?time_slab=#{start_time}.#{end_time}", 'throughput')# Graph is depicting the throughput for an application
      return avg_res_time_graph, app_throughput_graph
    end
    
    # This method renders the partial containing throughput Graphs for an application.
    def get_throughput_data(app_id)
      @app_id = app_id
      check_and_set_query_date
      @avg_res_time_graph, @app_throughput_graph = get_throughput_graph(@app_id)
      render :partial => 'throughput_graph'
    end
    
    # This method is called for getting the an applications average response graph for a specific date and time.
    def average_response_graph
      app_id = params[:app_id]
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])	
      if time_array.size > 1
        avg_res_time_graph = plot_graph("graph/get_average_response_data/#{app_id}?time_slab=#{time_array[0]}.#{time_array[1]}", 'server_memory_usage')
        render :text => avg_res_time_graph 
      else
        render :text => time_array[0]
      end
    end
    
    #This method is used to get the data for average respose for a specific application from the AppTimeSample model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_average_response_data
      app_id = params[:id]
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, response_time, max, slab, step = AppTimeSample.get_application_data(app_id, start_time, end_time, "averageresponsetime")
      line_graph(wall_time, response_time, AVERAGE_RESPONSE_TIME_GRAPH_TITLE, max, slab, step, "Wall Time","Time (in ms)")
    end
    
    # This method is called for getting the an applications throughput graph for a specific date and time.
    def peak_requests_graph
      app_id = params[:app_id]
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])	
      if time_array.size > 1
        app_throughput_graph = plot_graph("graph/get_peak_requests_data/#{app_id}?time_slab=#{time_array[0]}.#{time_array[1]}", 'throughput')
        render :text => app_throughput_graph 
      else
        render :text => time_array[0]
      end
    end
    
    #This method is used to get the data for throughput for a specific application from the AppTimeSample model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_peak_requests_data
      app_id = params[:id]
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, throughput, max, slab, step = AppTimeSample.get_application_data(app_id, start_time, end_time, "throughput")
      line_graph(wall_time, throughput, REQUEST_PER_SECOND_GRAPH_TITLE, max, slab, step,"Wall Time","Req/sec")
    end
  end
end
