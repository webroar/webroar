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

#This controller deals with the graph plotting and retriving the data for the graphs using models.
#This Controller additionally neads the module for each graph type saved in /lib/graph_controller_extensions.
Dir["#{RAILS_ROOT}/lib/graph_controller_extensions/*.rb"].each { |extension| require extension}
class GraphController < ApplicationController
  before_filter :login_required
  before_filter :clear_flash_notice
  before_filter :check_session_timeout
  skip_before_filter :verify_authenticity_token
  include Analytics::ResourceUsage
  include Analytics::UrlBreakup
  include Analytics::Database
  include Analytics::Throughput
  include Analytics::Url
  
  #This action renders the Analytics page.
  #This tab displayed the url breakdown information as a default if there is some application hosted in the server else it  shows the server stats.
  def index
    @apps = get_application_list    
    session[:graph_type] = "URL-Breakup" unless session[:graph_type]    
    get_graphs()
    if @apps[0] == SERVER_NAME
      session[:exceptions_application_name] = nil
    else
      session[:exceptions_application_name] = get_application_list_for_exceptions[0]
    end
  end
  
  # This method will give the details and initial graphs for the selected application.
  # This method is called when the application is selected from the select box for selecting application on index page of the graph controller.
  def get_next_app
    if params[:application_name]
      @application_name = params[:application_name]
    else
      @application_name = session[:application_name]
    end
    session[:application_name] = @application_name    
    session[:graph_type] = "URL-Breakup"
    get_graphs()
    render :partial => 'graph_page'
  end
  
  # This method is to display the different type of graphs as per the user selection from the populated select box.
  # This method gets its input from the select box named as "Select Graph".
  # This method call the method as per the grpah name supplied from the select box.
  def get_next_graph
    app_id = params[:id]
    session[:graph_type] = params[:graph_name]
    case params[:graph_name]
    when "URL-Calls"
      get_url_data(app_id)
    when "Database-Usage"
      get_database_data(app_id)
    when "URL-Breakup"
      get_url_breakup_data(app_id)
    when "Throughput"
      get_throughput_data(app_id)
    when "Resource-Usage"
      get_resource_usage_data_app(app_id)
    end
  end
  
  #This method is called when the graphs are needed for a particular period.
  def url_breakup_graph    
    @urls = Array.new
    @app_id = params[:app_id]
    from_date_str = params[:from_date].strip
    to_date_str = params[:to_date].strip
    rv = check_for_valid_period(from_date_str, to_date_str)
    if rv.class == Array  
      # check_for_valid_period method would set Time object having hour minute and second value to zero
      # for entime we would change it 23:59:59  by adding 86399 seconds 
      check_and_set_query_period(rv[0], rv[1] + 86399)         
      @urls = UrlTimeSample.get_urls(session[:from_date], session[:to_date], @app_id)
      @start_time = session[:from_date].strftime("%Y/%m/%d")
      @end_time = session[:to_date].strftime("%Y/%m/%d")
      if @urls.size > 0
        @url_rank = 1
        @suffix = get_suffix(@url_rank)
        @data_x,@data_y,@url_breakup_graph,@data_actual_time = get_url_breakup_graph_data(@start_time, @end_time, @app_id, @urls)       
      else
        flash[:notice] = NO_URL_HITS
      end              
      render :partial => 'url_breakup_graph'
    else
      render :text => rv, :status => 404
    end
  end
  
  def url_calls_graph
    @app_id = params[:app_id]
    from_date_str = params[:from_date].strip
    to_date_str = params[:to_date].strip
    rv = check_for_valid_period(from_date_str, to_date_str)
    if rv.class == Array  
      # check_for_valid_period method would set Time object having hour minute and second value to zero
      # for entime we would change it 23:59:59  by adding 86399 seconds 
      check_and_set_query_period(rv[0], rv[1] + 86399)      
      @url_hits_graph, @slowest_url_graph, @time_consuming_url_graph, @db_consuming_url_graph = get_url_calls_graph(@app_id)
      render :partial => 'url_calls_graph'      
    else
      render :text => rv, :status => 404
    end       
  end
  
  def database_usage_graph
    @app_id = params[:app_id]    
    # if date is changed from calendar popup, we would get only date
    # if slider is changed, we would get date and hour
    date_str = params[:date].strip
    rv = check_for_valid_query_date(date_str)
    if rv.class == Array
      check_and_set_query_date(rv[0])      
      @percentage_db_usage_graph = get_database_usage_graph(@app_id)
      render :partial => 'database_usage_graph'
      #puts @percentage_db_usage_graph      
    else
      render :text => rv, :status => 404
    end    
  end
  
  def resource_usage_graph_app
    @app_id = params[:app_id]    
    # if date is changed from calendar popup, we would get only date
    # if slider is changed, we would get date and hour
    date_str = params[:date].strip
    rv = check_for_valid_query_date(date_str)
    if rv.class == Array
      check_and_set_query_date(rv[0])      
      @app_cpu_usage_graph,@app_memory_usage_graph = get_resource_usage_graph_app(@app_id)
      render :partial=> 'resource_usage_graph_app'      
    else
      render :text => rv, :status => 404
    end    
    
  end
  
  def throughput_graph
    @app_id = params[:app_id]    
    # if date is changed from calendar popup, we would get only date
    # if slider is changed, we would get date and hour
    date_str = params[:date].strip
    rv = check_for_valid_query_date(date_str)
    if rv.class == Array
      check_and_set_query_date(rv[0])      
      @avg_res_time_graph,@app_throughput_graph = get_throughput_graph(@app_id)   
      render :partial => 'throughput_graph'   
    else
      render :text => rv, :status => 404
    end
  end
  
  def resource_usage_graph_server        
    # if date is changed from calendar popup, we would get only date
    # if slider is changed, we would get date and hour
    date_str = params[:date].strip
    rv = check_for_valid_query_date(date_str)
    if rv.class == Array
      check_and_set_query_date(rv[0])      
      @server_cpu_usage_graph, @server_memory_usage_graph = get_resource_usage_graph_server()
      render :partial => 'resource_usage_graph_server'
    else
      render :text => rv, :status => 404
    end    
  end
  
  #This method is to plot the line graph for the data supplied to the method.
  def line_graph(x_data, y_data, title, max=300, slab=30, step=3, x_legend="", y_legend="")
    title = OFC2::Title.new(:text => title)
    x_legend, y_legend = get_legends_for_graphs(x_legend, y_legend)
    line = OFC2::Line.new 
    line_values=[]
    count = 0
    y_data.each do |y|
       if y.nil?
         line_values << y
       else      
         line_values << OFC2::Dot.new(:value => y, :tip => "At #{x_data[count]} value is #{round(y)}")
       end
       count += 1
    end    
    line.values = line_values
    line.text = ''
    x, y = get_labels_for_graph(x_data, max, slab, step)
    draw_chart(x, y, x_legend, y_legend, title, line)
  end
  
  #This method is to plot the bar graph for the data supplied to the method.
  def bar_graph(x_data, y_data, title, max=300, slab=30, x_legend="", y_legend="")
    title = OFC2::Title.new(:text => title)
    bar = OFC2::BarGlass.new
    bar_values = []
    count = 0
    y_data.each do |y|
       if y == 0
         bar_values << y
       else      
         bar_values << OFC2::BarValue.new(:top => y, :tip => "#{round(y)}(#{x_data[count]})")
         #bar_values << OFC2::BarValue.new(:top => y, :colour => '#000000', :tip => "#{round(y)}(#{x_data[count]})")
       end  
       count += 1
    end
    bar.values = bar_values
    bar.text = ''
    x_legend, y_legend = get_legends_for_graphs(x_legend, y_legend)
    x, y = get_labels_for_graph(x_data, max, slab, 1)
    draw_chart(x,y,x_legend,y_legend,title,bar)
  end
  
  def horizontal_graph(x_data, y_data, title, max=300, slab=30, x_legend="", y_legend="")
    title = OFC2::Title.new(:text => title)
    data = []
    y_data.each do |i|
      if i != 0
        data << OFC2::HBarValue.new(:left => 0, :right => i)
      else
        data << i
      end
    end
    bar = OFC2::HBar.new
    bar.values = data
    bar.set_tooltip("")
    bar.text = ''
    x_labels = OFC2::XAxisLabels.new
    labels= []
    if max < 10 
      labels = ['0','1','2','3','4','5','6','7','8','9']
    else
      # TODO find some way to prevent empty label creation, max could be 1,000,000 and gives unnecessary overhead to server and client
      # http://teethgrinder.co.uk/open-flash-chart-2/x-axis-labels-step.php 
      0.upto(max) do |i|
        if i % slab == 0
          labels << i.to_s
        else    
          labels << ''
        end
      end
      x_labels.steps = slab
    end
    x_labels.labels = labels
    x = OFC2::XAxis.new
    x.labels = x_labels
    x.steps = slab
    x.offset = false
    y = OFC2::YAxis.new
    y.offset = true
    y.labels = x_data.reverse
    x_legend, y_legend = get_legends_for_graphs(y_legend, x_legend.reverse)
    #draw_chart(x, y, x_legend, y_legend, title, bar)

    tooltip = OFC2::Tooltip.new
    tooltip.set_hover()
    tooltip.mouse = 2
    tooltip.set_stroke(1)
    tooltip.set_backgroung_colour("#ffffff")
    tooltip.set_colour("#000000")

    chart = OFC2::Graph.new
    title.set_style("{font-size: 15px; color: #990B0A; text-align: center;font-weight: bold;}")
    chart.title = title
    chart << bar
    chart.x_axis = x
    chart.y_axis = y
    chart.bg_colour = '#FFFFFF'
    x.grid_colour = "#E9EAEC"
    y.grid_colour = "#E9EAEC"
    x.colour = "#000000"
    y.colour = "#000000"
    x.labels.style = "{font-size: 30px; color:#0000ff; font-family: Verdana;}"
    bar.colour = "#990B0A"
    chart.set_x_legend(x_legend)
    chart.set_y_legend(y_legend)
    chart.set_tooltip(tooltip)
    render :text => chart.render
  end  
 
  #This method is to set the legends for either of the line or bar graph.
  def get_legends_for_graphs(x_legend, y_legend)
    x_legend = OFC2::XLegend.new(:text => x_legend)
    y_legend = OFC2::YLegend.new(:text => y_legend)
    x_legend.set_style('{font-size: 12px; color: #990B0A;}')
    y_legend.set_style('{font-size: 12px; color: #990B0A;}')
    return x_legend, y_legend
  end
  
  #This methos is to label the X and Y axis for either of the line or bar graph.
  def get_labels_for_graph(x_data, max, slab, steps)
    x = OFC2::XAxis.new
    y = OFC2::YAxis.new(:min => 0, :max => max, :steps => slab)
    x_labels = OFC2::XAxisLabels.new
    x_labels.rotate = 'diagonal'
    x_labels.set_size(12)
    x_labels.set_labels x_data
    x_labels.set_steps(steps)
    x.set_labels x_labels
    x.set_steps(steps) if steps > 0	
    return x, y
  end
  
  #This method is used to draw the line or bar graph.
  def draw_chart(x, y, x_legend, y_legend, title, line)
    chart = OFC2::Graph.new
    title.set_style("{font-size: 15px; color: #990B0A; text-align: center;font-weight: bold;}")
    chart.title = title
    chart << line
    chart.x_axis = x
    chart.y_axis = y
    chart.bg_colour = '#FFFFFF'
    x.grid_colour = "#E9EAEC"
    y.grid_colour = "#E9EAEC"
    x.colour = "#000000"
    y.colour = "#000000"
    x.labels.style = "{font-size: 30px; color:#0000ff; font-family: Verdana;}"
    line.colour = "#990B0A"
    chart.set_x_legend(x_legend)
    chart.set_y_legend(y_legend)   
    render :text => chart.render
  end
  
  #This method is to plot pie chart. 
  def pie
    data_1, title, data_x, data_y, data_actual_time = pie_data(params[:id], params[:url])
    color=["#d01f3c","#356aa0","#C79810","#cccccc","#ffcc00","#ff3300","#99cc00","#cc9900","#333300","#ffff00","#990000","#ffff00","#ff0033",
"#00ffff","#00cc33","#ff66ff","#3300cc","#0033ff","#ffccff","#ccccff","#cc33cc","#ff9933","#ffffff","#000000"]
    pie = OFC2::Pie.new
    pie.colours = color
    pie.start_angle = 35  
    pie.animate = true
    pie.radius = 130
    pie.values = data_1
    pie.label_colour = "#000000"
    chart = OFC2::Graph.new  
    chart.title = OFC2::Title.new(:text => title, :style => "{font-size: 15px; color: #990B0A; text-align: center;font-weight: bold;}")
    chart.bg_colour = '#FFFFFF'  
    chart << pie  
    render :text => chart.render
  end	
  
  private

  #Plot the graph
  def plot_graph(graph, title)
    if(title)
      graph = ofc2(540, 400, graph, PREFIX, title, PREFIX)
    else
      graph = ofc2(540, 400, graph, PREFIX)
    end
    graph
  end

  def get_time_range(time_slab)
    date_arr = time_slab.split(".")
    date_str = date_arr[0].split("/")
    start_hour = date_str[3]
    date_str1 = date_arr[1].split("/")
    end_hour = (date_str1[3] == "0" ? "24" : date_str1[3])
    if start_hour.to_i != end_hour.to_i	
	    end_hour = end_hour.to_i-1
	    start_time = Time.local(date_str[0], date_str[1], date_str[2], start_hour, "00", "00")
	    end_time = Time.local(date_str1[0], date_str1[1], date_str1[2], end_hour, "59", "00")
    else
	if start_hour.to_i == 0
	    start_time = Time.local(date_str[0], date_str[1], date_str[2], start_hour, "00", "00")
	    end_time = Time.local(date_str1[0], date_str1[1], date_str1[2], end_hour, "00", "00")
	else 
	    start_hour = start_hour.to_i-1
	    end_hour = end_hour.to_i-1
	    start_time = Time.local(date_str[0], date_str[1], date_str[2], start_hour, "00", "00")
	    end_time = Time.local(date_str1[0], date_str1[1], date_str1[2], end_hour, "00", "00")
	end
    end	
    return start_time, end_time
  end
  
  #This method is used to get the date from the paramaters supplied with call to an action and returns it to the action with the date.
  def get_date_for_bar_graphs
    return [session[:from_date], session[:to_date] ]
  end
  
  # This method gives the type of the graph to be rendered and set the values to the respective graph instance 
  # varriables.
  def get_graphs()    
    # keeping 7 days as default period to query the data.
    check_and_set_query_period() 
    # keeping today's date as default query date
    check_and_set_query_date()
    date = session[:start_time].strftime("%Y/%m/%d/%H")
    if session[:application_name] != SERVER_NAME
      application = App.get_application_data(@application_name)
      @app_id = application.id
      case session[:graph_type]
      when "URL-Calls"
        @url_hits_graph, @slowest_url_graph, @time_consuming_url_graph, @db_consuming_url_graph = get_url_calls_graph(@app_id)
      when "Database-Usage"
        @percentage_db_usage_graph = get_database_usage_graph(@app_id)
      when "URL-Breakup"
        @start_time = session[:from_date].strftime("%Y/%m/%d")
        start_time = session[:from_date]
        @end_time = session[:to_date].strftime("%Y/%m/%d")
        end_time = session[:to_date]
        @urls = UrlTimeSample.get_urls(start_time, end_time, @app_id)
        if @urls.size > 0
          @url_rank = 1
          @suffix = get_suffix(@url_rank)
          @data_x, @data_y, @url_breakup_graph, @data_actual_time = get_url_breakup_graph_data(@start_time, @end_time, @app_id, @urls)
        end
      when "Throughput"
        @avg_res_time_graph, @app_throughput_graph = get_throughput_graph(@app_id)
      when "Resource-Usage"
        @app_cpu_usage_graph, @app_memory_usage_graph = get_resource_usage_graph_app(@app_id)
      else
        flash[:notice]="No data for the application #{@application_name}"
      end
    else
      @server_cpu_usage_graph, @server_memory_usage_graph = get_resource_usage_graph_server()
    end
  end

  def get_date_array(str_date)
    date_array = str_date.split(" ")
    month = MONTHS[date_array[0]]
    day = date_array[1].to_i
    year = date_array[2].to_i
    [month, day, year]
  end
  
  #This method is used to check validity of the date enterd by the user in any of the graph.
  #It checks whether the date is a valid date or not.
  def check_for_valid_date(date) # input format is "mm/dd/yyyy"
    if /^(january|february|march|april|may|june|july|august|september|october|november|december) ([1-9]|[0][1-9]|[1-2][0-9]|[3][0-1]), [0-9]{4}$/i.match(date)
      date_arr = get_date_array(date)
     month = date_arr[0]
      day = date_arr[1]
      year = date_arr[2]
      if month == 2 and day < 30 and find_leap_year(year)
        return true
      elsif month == 2 and day < 29 and !find_leap_year(year)
        return true
      elsif !%w{1 3 5 7 8 10 12}.index(month.to_s).nil? and day <= 31
        return true
      elsif !%w{4 6 9 11}.index(month.to_s).nil? and day < 31
        return true
      else
        return false
      end
    else
      return false   
    end
  end
  
  # This method is to check validity of passed date parameters, from_date <= to_date <= today
  # Returns an array having From Date and  To Date or failure message. 
  # Returned failure message would be used to render as text
  def check_for_valid_period(from_date_str, to_date_str)    
    text_res = "" 
    unless check_for_valid_date(from_date_str)    
      from_date_str = nil
      text_res += INVALID_FROM_DATE + BR 
    end
    unless check_for_valid_date(to_date_str)    
      to_date_str = nil
      text_res += INVALID_TO_DATE + BR
    end
    if from_date_str and to_date_str
      text_res = ""
      from_date_parts = get_date_array(from_date_str)
      to_date_parts = get_date_array(to_date_str)
      # it would set Time object having hour minute and second value to zero
      from_date = Time.local(from_date_parts[2], from_date_parts[0], from_date_parts[1])
      to_date = Time.local(to_date_parts[2], to_date_parts[0], to_date_parts[1])
      if from_date > to_date
        text_res += FROM_DATE_GREATERTHAN_TO_DATE
      end
      if to_date > Time.now
        text_res += TO_DATE_GREATERTHAN_TODAY
      end
      if text_res == ""
        [from_date, to_date]
      else
        text_res
      end      
    else
      text_res
    end    
  end
  
  # check for valid date_str(mm/dd/yyyy) and hour_str
  # on succes return Array having date(Time object) and hour_str, 
  # on failure return error message 
  def check_for_valid_query_date(date_str)
    rv = ''    
    if date_str 
      if check_for_valid_date(date_str)
        date_parts = get_date_array(date_str)
        date = Time.local(date_parts[2], date_parts[0], date_parts[1])
        if date > Time.now
          rv += FUTURE_DATE
          date_err = true
        else
          date_err = false
        end
      else
        rv += INVALID_DATE  
        date_err = true
      end
    end
    if date_err 
      rv
    else
      [date]
    end    
  end
  
  #This method is used to check the whether the year supplied to the method is a leap year or not.
  def find_leap_year(year)
    if (year%4 == 0 and year%100 != 0) or (year%100 == 0 and year%400 == 0)
      return true
    else
      return false
    end
  end
  
  #to add suffix to the ranks of the most time consuming urls
  def get_suffix(rank)
    suffix = "th"
    if rank%10 == 1 and rank != 11
      suffix = "st"
    elsif rank%10 == 2 and rank != 12
      suffix = "nd"
    elsif rank%10 == 3 and rank != 13
      suffix = "rd"
    end
    return 	suffix
  end
  
  # if dates are given, it would set session variables accordingly
  # otherwise it would set default period of 7 days
  def check_and_set_query_period(from_date = nil, to_date = nil)      
    unless session[:from_date] or session[:to_date] 
      session[:to_date] = Time.local(Time.now.year, Time.now.month, Time.now.day, '23',  '59', '59')
      session[:from_date] = session[:to_date] - (86400 * 7)
    end
    if from_date and to_date
      session[:from_date] = Time.local(from_date.year, from_date.month, from_date.day, '0', '0', '0')
      session[:to_date] = Time.local(to_date.year, to_date.month, to_date.day, '23', '59', '59')      
    end     
  end
  
  def check_and_set_query_date(date = nil)
    unless session[:start_time]
      session[:start_time] = Time.local(Time.now.year, Time.now.month, Time.now.day, Time.now.hour, '0', '0')
    end
    if date
      session[:start_time] = Time.local(date.year, date.month, date.day, '0', '0', '0')
    end
  end		

  def get_start_end_time(date, start_time, end_time)
    if date and check_for_valid_date(date) 
      date_array = get_date_array(date)
      date = date_array[2].to_s+"/"+date_array[0].to_s+"/"+date_array[1].to_s  # date is in format "yyyy/dd/mm"
        start_time = date+"/"+start_time
        end_time = date+"/"+end_time
        [start_time, end_time]
    else
      [INVALID_DATE]
    end 
  end
	
  def get_start_and_end_time_from_session()	
      start_hour = 0
      if session[:start_time] < Time.local(Time.now.year, Time.now.month, Time.now.day, "0","0","0")
	      end_hour = 24
      else
        end_hour = (Time.now.advance(:hours => 1)).hour
      end	
      start_time = "#{session[:start_time].year}/#{session[:start_time].month}/#{session[:start_time].day}/#{start_hour}"
      end_time = "#{session[:start_time].year}/#{session[:start_time].month}/#{session[:start_time].day}/#{end_hour}"
     return start_hour, end_hour, start_time, end_time
  end

end
