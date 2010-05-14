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

#This controller deals with all the actions related to the user handling and application configuration. 
class AdminController < ApplicationController
  before_filter :login_required, :except => ['index', 'login'] #This method checks whether user is authenticated or not.
  before_filter :check_session_timeout, :except => ['index', 'login', 'get_latest_app_cpu_usage', 'get_latest_app_memory_usage', 'get_latest_server_cpu_usage', 'get_latest_server_memory_usage', 'get_latest_time']
  #before_filter :clear_flash_notice #This methos clear the flash notice messages before navigating to next action.
  protect_from_forgery :only => [:change_password ]
  ssl_required :index, :login, :change_password, :change_password_form if SSL_ON

  #This action is to render the login page with the layout index.html.erb.
  #If the user session is already created the it redirects the control to the home page of the admin panel.
  def index
    if session[:user]
      redirect_to home_path
    else
      @user = User.new
      render :action => 'index', :layout => 'index'
    end
  end
  
  #This action is for displaying the first page i.e Home page of the Admin Panel.
  #This page contains the server snapshot(i.e. its cpu and memory usgae) 
  #and the list of application deployed on the server with its cpu and memory usgae.	
  def home
    @info = YAML::load_file(CONFIG_FILE_PATH) rescue nil #To get the data of yaml file into yaml object
    @server_resource_usage = ResourceUsage.get_latest_for_server #To get the resource usage by the server 
    @apps_resource_usage = ResourceUsage.get_latest_for_apps # to get the resource usage by the application
    set_application_name
  end
  
  # This function is to dynamically update the server's CPU usage.
  # After a minute it refreshes the cpu usage. 
  def get_latest_server_cpu_usage
    render :text => ResourceUsage.get_latest_for_server[0] 
  end
  
  # This function is to dynamically update the server's memory usage.
  # After a minute it refreshes the memory usage of the server.
  def get_latest_server_memory_usage
    render :text => format("%.2f",ResourceUsage.get_latest_for_server[1]/1024.to_f)
  end
  
  # This function is to dynamically update the application's CPU usage
  # After a minute it refreshes the cpu usage for a particalar application.	
  def get_latest_app_cpu_usage
    apps_resource_usage = ResourceUsage.get_latest_for_apps
    if params[:app_name] and apps_resource_usage[params[:app_name]]
      render :text => apps_resource_usage[params[:app_name]][0].to_s
    else
      render :text => "0.0"
    end
  end
  
  # This function is to dynamically update the application's Memory usage.
  # After a minute it refreshes the memory usage for a particalar application.	
  def get_latest_app_memory_usage
    apps_resource_usage = ResourceUsage.get_latest_for_apps
    if params[:app_name] and apps_resource_usage[params[:app_name]]
      render :text => format("%.2f",apps_resource_usage[params[:app_name]][1] / 1024.to_f)	
    else
      render :text => "0.0"
    end
  end
  
  # This function is to get the details of config file for configuration page.
  # This page contains the server settings and the application settings.
  def configuration			
    @info= YAML::load_file(CONFIG_FILE_PATH)	rescue nil
    @ssl_spec = Hash[:certificate_path => params[:ssl][:certificate_path],
      :key_path => params[:ssl][:key_path],
      :port => params[:ssl][:port]] if params[:ssl]
    @sendmail_old = params[:sendmail] if params[:sendmail]
    @smtp_old = params[:smtp] if params[:smtp]
    set_application_name
  end
  
  #This action is called for login authentication. For user authentication it used a method "user_authentication" present in the application.rb.
  #It takes user hash as a input from the login page.
  def login
    if request.post?      
      rv = User.authenticate(params[:user][:name], params[:user][:password]) rescue nil      
      if rv == true
        session[:session_time] = Time.now
        session[:user] = params[:user][:name]
        flash[:notice] = nil
        if session[:referer]
          referer_path = session[:referer]
          session[:referer] = nil
          redirect_to referer_path
        else
          redirect_to root_path      
        end            
      else
        flash[:notice] = rv
        render :action => 'index', :layout => 'index'
      end      
    end
  end
  
  #This function is for deleting the session of a user.
  #By clearing the session data for a specific user it delete the sesion of a user.
  def logout
    reset_session
    flash[:notice] = SUCCESSFUL_LOGOUT
    redirect_to root_path
  end
   
  #The action is to change the password of the admin panel user.
  def change_password
    set_application_name
    password_changed = false
    users = YAML::load_file(USERS_FILE_PATH) rescue nil
    users.each do |user|
      if user['user_name'] == session[:user] &&  user['password'] == Digest::MD5.hexdigest(params[:password][:old]) && params[:password][:new] == params[:password][:confirm] && params[:password][:new].length > 5 
        user['password'] = Digest::MD5.hexdigest(params[:password][:new])
        password_changed = true
        break
      end
    end
    if password_changed
      flash[:notice] = PASSWORD_CHANGED
      YAMLWriter.write(users,USERS_FILE_PATH,"user")
    else
      if params[:password][:new].length < 6
        flash[:notice] = WRONG_PASSWORD2
      else 
        flash[:notice] = WRONG_PASSWORD1
      end
      #TODO : This message is to be made more specific for old password and confirm password.
    end
    render :action => 'change_password_form'
  end
  
  #This method is used to render the Admin Panel Settings Page.	
  def change_password_form
    set_application_name
  end
  
  #This method is to return the server time.
  #The method refreshes the time after every minute.	
  def get_latest_time
    render :text =>  Time.now.strftime("%d %b %Y %H:%M")
  end
  
  #Used to paginate the list of deployed applications.
  def required_apps
    @info = YAML::load_file(CONFIG_FILE_PATH)	rescue nil
    render :partial => 'application_table', :locals => {:start => params[:start].to_i}
  end
  
  private
 
  #This methos is to set the application name and the url type in the session.
  #This method is called whenever action home, configuration or user settings is called. This is to set the default values for graph page in the session.
  def set_application_name
    apps = get_application_list
    session[:application_name] = apps[0]
    if apps[0] != SERVER_NAME
      session[:graph_type] = "URL-Breakup"
    end
    apps.delete(SERVER_NAME)
    session[:exceptions_application_name] = get_application_list_for_exceptions[0]
  end
end
