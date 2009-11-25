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

#This module is used to get the data for the Resource Usage Graphs i.e. Percentage CPU Utilization and Momory Utilization graphs.
module Analytics
  module ResourceUsage
    #This method is to populate the varriable server_cpu_usage_graph and server_memory_usage_graph with the respective graphs data.
    #server_cpu_usage_graph contains the data for server Percentage CPU usage.
    #server_memory_usage_graph contains the data for server Memory usage.
    def get_resource_usage_graph_server()
      @start_hour, @end_hour, start_time, end_time = get_start_and_end_time_from_session()      
      server_cpu_usage_graph = plot_graph("graph/get_server_cpu_usage?time_slab=#{start_time}.#{end_time}", 'server_cpu_usage') # Graph is depicting the server Cpu Utilization vs wall time
      server_memory_usage_graph = plot_graph("graph/get_server_memory_usage?time_slab=#{start_time}.#{end_time}", 'server_memory_usage') # Graph is depicting the server Memory Utilization vs wall time
      return server_cpu_usage_graph, server_memory_usage_graph
    end
    
    # This method is called for getting the server percentage cpu usage graph for a specific date and time.
    def get_server_cpu_usage_graph
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])
      if time_array.size>1
        @server_cpu_usage_graph = plot_graph("graph/get_server_cpu_usage?time_slab=#{time_array[0]}.#{time_array[1]}", 'server_cpu_usage')
        render :text => @server_cpu_usage_graph
      else
        render :text => time_array[0]
      end
    end
    
    #This method is used to get the data for server percentage cpu usage from the ResourceUsage model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_server_cpu_usage
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, cpu_usage, max, slab, step = ::ResourceUsage.get_server_resource_usage(start_time,end_time, "CPU")
      line_graph(wall_time, cpu_usage, CPU_USGAE_GRAPH_TITLE, max, slab, step, "Wall Time", "% CPU Usage")
    end
    
    # This method is called for getting the server memory usage graph for a specific date and time.
    def get_server_memory_usage_graph
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])	
      if time_array.size > 1
        @server_memory_usage_graph = plot_graph("graph/get_server_memory_usage?time_slab=#{time_array[0]}.#{time_array[1]}", 'server_memory_usage')
        render :text => @server_memory_usage_graph 
      else
        render :text => time_array[0]
      end
    end
    #This method is used to get the data for server memory usage from the ResourceUsage model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_server_memory_usage
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, memory_usage, max, slab, step = ::ResourceUsage.get_server_resource_usage(start_time, end_time, "Memory")
      line_graph(wall_time, memory_usage, MEMORY_USAGE_GRAPH_TITLE, max, slab, step, "Wall Time", "Memory (In MB)")
    end
    
    #This method is to populate the varriable app_cpu_usage_graph and app_memory_usage_graph with the respective graphs data.
    #app_cpu_usage_graph contains the data for Percentage CPU usage by a specfic application.
    #app_memory_usage_graph contains the data for Memory usage by a specfic application.

    def get_resource_usage_graph_app(app_id)
      @start_hour, @end_hour, start_time, end_time = get_start_and_end_time_from_session()
      app_cpu_usage_graph = plot_graph("graph/get_cpu_utilization/#{app_id}?time_slab=#{start_time}.#{end_time}", 'cpu_utilization')#Graph depicts the cpu utilization
      app_memory_usage_graph = plot_graph("graph/get_memory_utilization/#{app_id}?time_slab=#{start_time}.#{end_time}", 'memory_utilization')#Graph depicts the memory utilization
      return app_cpu_usage_graph, app_memory_usage_graph
    end
    
    # This method renders the partial containing resource usage Graphs for an application.
    def get_resource_usage_data_app(app_id)
      @app_id = app_id
      check_and_set_query_date
      @app_cpu_usage_graph, @app_memory_usage_graph = get_resource_usage_graph_app(@app_id)
      render :partial => 'resource_usage_graph_app'
    end
    
    # This method is called for getting the an applications percentage cpu usage graph for a specific date and time.
    def percentage_cpu_usage_graph
      app_id = params[:app_id]
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])	
      if time_array.size>1
        app_cpu_usage_graph = plot_graph("graph/get_cpu_utilization/#{app_id}?time_slab=#{time_array[0]}.#{time_array[1]}", 'cpu_utilization')
        render :text => app_cpu_usage_graph
      else
        render :text => time_array[0]
      end
    end
    
    #This method is used to get the data for percentage cpu usage for a specific application from the ResourceUsage model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_cpu_utilization
      app_id = params[:id]
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, cpu_usage, max, slab, step = ::ResourceUsage.get_application_data(app_id, start_time, end_time, "cpu")
      line_graph(wall_time, cpu_usage, CPU_USGAE_GRAPH_TITLE, max, slab, step, "Wall Time", "% CPU Usage")
    end
    
    # This method is called for getting the an applications memory usage graph for a specific date and time.
    def memory_usage_graph
      app_id = params[:app_id]
      time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])	
      if time_array.size > 1
        app_memory_usage_graph = plot_graph("graph/get_memory_utilization/#{app_id}?time_slab=#{time_array[0]}.#{time_array[1]}", 'memory_utilization')
        render :text => app_memory_usage_graph
      else
        render :text => time_array[0]
      end
    end
    
    #This method is used to get the data for memory usage for a specific application from the ResourceUsage model.
    #This data is supplied to the line graph method to plot the line graph.
    def get_memory_utilization
      app_id = params[:id]
      start_time, end_time = get_time_range(params[:time_slab])
      wall_time, memory_usage, max, slab, step = ::ResourceUsage.get_application_data(app_id, start_time, end_time, "memory")
      line_graph(wall_time, memory_usage, MEMORY_USAGE_GRAPH_TITLE, max, slab, step, "Wall Time", "Memory (in MB)")
    end
  end
end
