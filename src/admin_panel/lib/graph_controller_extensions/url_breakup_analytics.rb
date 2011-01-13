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

#This module is used to get the data for the Url breakdown pie Graphs.
module Analytics
  module UrlBreakup
    #This method gives the details of url calls and there time spent by the url in different place i.e in database,rendering etc. and it also returns the pie graph data for the same.
    def get_url_breakup_graph_data(start_time, end_time, app_id, urls)
      url = urls[0]
      data_1, url_name, data_x, data_y, data_actual_time = pie_data(app_id,"#{url}-#{start_time}-#{end_time}")
      data_x = data_x
      data_y = data_y
      url_breakup_graph = plot_graph("graph/pie/#{app_id}?url=#{url}-#{start_time}-#{end_time}", 'pie')
      return data_x, data_y, url_breakup_graph, data_actual_time
    end
    
    #This method gives the percentage time taken by a url in different parts like database and rendering etc.
    def pie_data(app_id, url_data)
      data_str = url_data.split("-")
      url_name = data_str[0]
      date_str = data_str[1].split("/")
      start_time = Time.local(date_str[0],date_str[1],date_str[2])
      date_str = data_str[2].split("/")
      end_time = Time.local(date_str[0],date_str[1],date_str[2], '23', '59', '59')
      
      url_sample = UrlTimeSample.get_url_data(start_time, end_time, app_id, url_name)
      
      db_time = round((url_sample[0].db_time.to_f*100/url_sample[0].total_time.to_f).to_f)
      rendering_time = round(url_sample[0].rendering_time.to_f * 100 / url_sample[0].total_time.to_f)
      remaining_time = round(100 - db_time-rendering_time)
      data_x = Array.new
      data_y = Array.new
      data_actual_time = Array.new
      data_1 = Array.new
      if db_time > 0
        url_sample_ids = UrlTimeSample.get_url_id(start_time, end_time, url_name, app_id)
        url_id = Array.new
        url_sample_ids.each do |url_sample_id|
          url_id << url_sample_id.id
        end
        url_breakup_sample = UrlBreakupTimeSample.get_url_breakup_sample_data(url_id)
        url_breakup_sample.each do |url|
          time = (url.time_spent.to_f*100 / url_sample[0].total_time.to_f).to_f
          time = round(time)
          data_x << url.method_name
          data_y << time
          actual_time = round(url.time_spent.to_f / 1000)
          data_actual_time << actual_time
          method_name = data_x.length.to_s + ". " + url.method_name
          if method_name.length > 20
            method_name = method_name[0..16] + "..."
          end
          #data_1 << OFC2::PieValue.new(:value => time, :label => url.method_name, :tip => "#{actual_time} sec")
          data_1 << OFC2::PieValue.new(:value => time, :label => method_name, :tip => "#{actual_time} sec")
        end
        data_x << "Rendering Time"
        data_y << rendering_time
        actual_time = round(url_sample[0].rendering_time.to_f/1000)
        data_actual_time << actual_time
        data_1 << OFC2::PieValue.new(:value => rendering_time, :label => 'Rendering Time', :tip => "#{actual_time} sec")
        data_x << "Remaining Time"
        data_y << remaining_time
        actual_time = round((url_sample[0].total_time.to_f-url_sample[0].rendering_time.to_f-url_sample[0].db_time.to_f)/1000)
        data_actual_time << actual_time
        data_1 << OFC2::PieValue.new(:value => remaining_time, :label => 'Remaining Time', :tip => "#{actual_time} sec")
      else
        data_x << "Rendering Time"
        data_y << rendering_time
        actual_time = round(url_sample[0].rendering_time.to_f/1000)
        data_actual_time << actual_time
        data_1 << OFC2::PieValue.new(:value => rendering_time, :label => 'Rendering Time', :tip => "#{actual_time} sec")
        data_x << "Remaining Time"
        data_y << remaining_time
        actual_time = round((url_sample[0].total_time.to_f-url_sample[0].rendering_time.to_f-url_sample[0].db_time.to_f)/1000)
        data_actual_time << actual_time
        data_1 << OFC2::PieValue.new(:value => remaining_time, :label => 'Remaining Time', :tip => "#{actual_time} sec")
      end
      return data_1, url_name, data_x, data_y, data_actual_time
    end
    
    #This method is called when the refresh button is clicked from the url_breakdown graph.
    def refresh_pie_graph
      app_id = params[:app_id]
      get_url_breakdown_data(app_id)
    end
    
    # This method render the pie graphs and its percentage time consumption table for the first url in 
    # the list of url for current day.
    def get_url_breakup_data(app_id)
      @app_id = app_id
      check_and_set_query_period()
      @start_time = session[:from_date].strftime("%Y/%m/%d")
      start_time = session[:from_date]
      @end_time = session[:to_date].strftime("%Y/%m/%d")
      end_time = session[:to_date]      
      @urls = UrlTimeSample.get_urls(start_time, end_time, app_id)
      if @urls.size > 0
        @url_rank = 1
        @suffix = get_suffix(@url_rank)
        @data_x, @data_y, @url_breakup_graph, @data_actual_time = get_url_breakup_graph_data(@start_time, @end_time, @app_id, @urls)
      else
        flash[:notice] = NO_DATA_FOUND
      end
      render :partial => "url_breakup_graph"
    end
    
    #This method renders the pie graph and time consumption details for a specific url listed in the select box.
    def get_url_breakdown
      app_id = params[:id]
      start_time = params[:start_time]
      end_time = params[:end_time]
      url = params[:url_name]
      if params[:index]
        @url_rank = params[:index].to_i + 1
        @suffix = get_suffix(@url_rank)
      end
      @data_x, @data_y, @url_breakup_graph, @data_actual_time = get_url_breakup_graph_data(start_time, end_time, app_id, Array[url])
      render :partial => 'pie'
    end
    
    #This function rounds of the float upto 2 decimal places
    def round(value)
      return sprintf("%0.2f",value).to_f
    end
  end
end
