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

#This module is used to get the data for the Database Usage Graphs i.e. Top database consuming urls and Percentage time spent in database layer graphs.
module Analytics
  module Database
    #This method is to populate the varriable graph4 and graph9 with the respective graphs data.
    #graph4 contains the data for the Percentage time spent in database layer graph.
    #graph9 contains the data for the Top database consuming urls graph.
    def get_database_usage_graph(app_id)
    @start_hour, @end_hour, start_time, end_time = get_start_and_end_time_from_session()    
      percentage_db_usage_graph = plot_graph("graph/get_percentage_db_usage_data/#{app_id}?time_slab=#{start_time}.#{end_time}", 'percentage_db_usage')#Graph depicts the % database usage     
    end
    
    # This method renders the partial containing Database Usage Graphs.
    def get_database_data(app_id)
      @app_id = app_id
      check_and_set_query_date      
      @percentage_db_usage_graph = get_database_usage_graph(@app_id)
      render :partial => 'database_usage_graph'
    end
    
    # This method is called for getting the percentage time spent graph for a specific date and time.
    def percentage_time_spent_in_db_layer
        app_id = params[:app_id]
	time_array = get_start_end_time(params[:date], params[:start_time], params[:end_time])
        if time_array.size > 1
            @percentage_db_usage_graph = plot_graph("graph/get_percentage_db_usage_data/#{app_id}?time_slab=#{time_array[0]}.#{time_array[1]}", 'percentage_db_usage')
           render :text => @percentage_db_usage_graph
        else
            render :text => time_array[0]
        end
    end

   
    # This method is used to get the data for percentage db usage from the AppTimeSample model.
    # This data is supplied to the bar_grap method to plot the line graph.
    def get_percentage_db_usage_data
      start_time,end_time = get_time_range(params[:time_slab])
      app_id = params[:id]
      wall_time, db_time, max, slab, step = AppTimeSample.get_application_data(app_id, start_time, end_time, "db")
      line_graph(wall_time, db_time, PERCENTAGE_TIME_SPENT_IN_DATABASE_LAYER_GRAPH_TITLE, max, slab, step, "Wall Time", "% Time Spent")
    end   
  end
end
