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

#This module is used to get the data for the Url Calls Graphs i.e. Url hits,slowest url and top time consuming url graphs.
module Analytics
  module Url
    #This method is to populate the varriable url_hits_graph,slowest_url_graph and time_consuming_url_graph with the respective graphs data.
    #url_hits_graph contains the data for url hits for an application.
    #slowest_url_graph contains the data for slowest urls of an application.
    #time_consuming_url_graph contains the data for top time consuming urls of an application.
    def get_url_calls_graph(app_id)
      url_hits_graph = plot_graph("graph/get_url_hits_data/#{app_id}", 'url_hits')# Graph is depicting the application specific url hits
      slowest_url_graph = plot_graph("graph/get_slowest_url_data/#{app_id}", 'slowest_url')# Graph is depicting the Slowest Url
      time_consuming_url_graph = plot_graph("graph/get_time_consuming_url_data/#{app_id}", 'time_consuming_url')# Graph is depicting the Time consuming Url
      db_consuming_url_graph = plot_graph("graph/get_top_db_consuming_url_data/#{app_id}", 'top_db_consuming_url')#Graph depicts the top database consuming urls      
      return url_hits_graph, slowest_url_graph, time_consuming_url_graph, db_consuming_url_graph
    end
    
    # This method renders the partial containing url call Graphs for an application.
    def get_url_data(app_id)
      @app_id = app_id
      @url_hits_graph, @slowest_url_graph, @time_consuming_url_graph, @db_consuming_url_graph = get_url_calls_graph(app_id)
      render :partial => 'url_calls_graph'
    end
       
    #This method is used to get the data for url hits for a specific application from the UrlTimeSample model.
    #This data is supplied to the bar graph method to plot the bar graph.
    def get_url_hits_data
      app_id = params[:id].to_i
      from_date, to_date = get_date_for_bar_graphs
      urls,number_of_requests,max,slab = UrlTimeSample.get_url_calls_data(app_id, from_date, to_date, "requests")
#      bar_graph(urls,number_of_requests, URL_HITS_GRAPH_TITLE, max, slab, "", "Number of Hits")
      horizontal_graph(urls,number_of_requests, URL_HITS_GRAPH_TITLE, max, slab, "", "Number of Hits")
    end
        
    #This method is used to get the data for slowest urls for a specific application from the UrlTimeSample model.
    #This data is supplied to the bar graph method to plot the bar graph.
    def get_slowest_url_data
      app_id = params[:id].to_i
      from_date, to_date = get_date_for_bar_graphs  
      urls, time, max, slab = UrlTimeSample.get_url_calls_data(app_id, from_date, to_date, "slowesturl")
#      bar_graph(urls, time, SLOWEST_URLS_GRAPH_TITLE, max, slab, "", "Average Time (in ms)")
      horizontal_graph(urls, time, SLOWEST_URLS_GRAPH_TITLE, max, slab, "", "Average Time (in ms)")      
    end
        
    # This method is used to get the data for time consuming urls for a specific application from the UrlTimeSample model.
    # This data is supplied to the bar graph method to plot the bar graph.
    def get_time_consuming_url_data 
      app_id = params[:id].to_i      
      from_date, to_date = get_date_for_bar_graphs      
      urls, time, max, slab = UrlTimeSample.get_url_calls_data(app_id, from_date, to_date, "timeconsumingurl")
#      bar_graph(urls, time, MOST_TIME_CONSUMING_GRAPH_TITLE, max, slab, "", "Total Time (in seconds)")
      horizontal_graph(urls, time, MOST_TIME_CONSUMING_GRAPH_TITLE, max, slab, "", "Total Time (in seconds)")
    end   
        
    #This method is used to get the data for top db consuming urls percentage db usage data from the UrlTimeSample model.
    #This data is supplied to the bar_grapd method to plot the bar graph.
    def get_top_db_consuming_url_data
      app_id = params[:id].to_i
      from_date, to_date = get_date_for_bar_graphs
      urls, time, max, slab = UrlTimeSample.get_url_calls_data(app_id, from_date, to_date, "dbcosumingurl")
#      bar_graph(urls, time, TOP_DATABASE_CONSUMING_URLS_GRAPH_TITLE, max, slab,"", "Time (in seconds)")
      horizontal_graph(urls, time, TOP_DATABASE_CONSUMING_URLS_GRAPH_TITLE, max, slab,"", "Time (in seconds)")
    end    
  end
end
