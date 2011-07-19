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
  before_filter :check_session_timeout, :except => ['index', 'login', 'get_latest_updates', 'get_latest_time']
  before_filter :clear_flash_notice, :only => [:change_password_form,:contact_us,:send_feedback,:send_report_bug]
  #before_filter :clear_flash_notice #This methos clear the flash notice messages before navigating to next action.
  protect_from_forgery :only => [:change_password ]
  ssl_required :index, :login, :change_password, :change_password_form if SSL_ON
  before_filter :create_question_captcha, :only => [:contact_us]
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
  
  # This function is to get the details of config file for configuration page.
  # This page contains the server settings and the application settings.
  def configuration			
    @info= YAML::load_file(CONFIG_FILE_PATH)	rescue nil
    @applications = App.get_all(1)
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
      YAMLWriter.write(users, USERS_FILE_PATH, YAMLConfig::USER)
      reset_session
      flash[:notice] = PASSWORD_CHANGED
      redirect_to root_path
    else
      if params[:password][:new].length < 6
        flash[:notice] = WRONG_PASSWORD2
      else 
        flash[:notice] = WRONG_PASSWORD1
      end
      render :action => 'change_password_form'
      #TODO : This message is to be made more specific for old password and confirm password.
    end
  end
  
  #This method is used to render the Admin Panel Settings Page.	
  def change_password_form
    set_application_name
  end
  
  #Update all the dynamic values on home page
  def get_latest_updates
    server_usage = ResourceUsage.get_latest_for_server
    apps_usage = ResourceUsage.get_latest_for_apps_with_exceptions
    str = "<script>
        loadDivs(new Array('server_cpu_usage','#{"%.2f" % server_usage[0]}','server_memory_usage','#{"%.2f" % (server_usage[1].to_f/1024)}'"

         apps_usage.each do |key, val|
          unless key[" "] or key == 'static-worker'
            str<<",'#{key}_cpu','#{"%.2f" % val[0]}','#{key}_memory','#{"%.2f" % (val[1].to_f/1024)}','#{key}_exception','#{val[2]}'"
          end
        end
        str << "));</script>"

    render :text => str
  end

  #This method is to return the server time.
  #The method refreshes the time after every minute.	
  def get_latest_time
    render :text =>  Time.now.strftime("%d %b %Y %H:%M")
  end
  
  #Used to paginate the list of deployed applications.
  def required_apps
    @info = YAML::load_file(CONFIG_FILE_PATH)	rescue nil
    @applications = App.get_all(params[:page] || 1)
    render :update do |page|
      page.replace_html 'application_list_table', :partial => 'application_table'
    end
  end
  
  # This method is used to render the report_bug, feedback
  # and contact_us form on the basis of params[:form_name]
  def contact_us
    flash[:notice] = Mailer.check_smtp_mail_settings
    @rb = {:name => "" ,:email => "",:subject => "",:description => ""}
    @fb = {:name => "" ,:email => "",:message => ""}
    case params[:form_name]
      when "report_bug"
        render :partial => "report_bug_partial"
      when "feedback"
        render :partial => "feedback_partial"
      else
        render "contact_us"
    end
  end

  # this method is used to send the feedback
  def send_feedback
    @fb = feedback = params[:feedback]
    message = MailSpecification.validate_feedback_data(feedback)
    if message == ""
      if validate_captcha_answer
        @fb = {:name => "" ,:email => "",:message => ""}
        flash[:notice] = Mailer.send_feedback(feedback)
      end
    else
      flash[:notice] = message
    end
    render :partial => 'feedback_partial'
  end

  # this method is used to report the bug
  def send_report_bug
    @rb = report_bug = params[:report_bug]
    message = MailSpecification.validate_report_bug_data(report_bug)
    if message == ""
      if validate_captcha_answer
        @rb = {:name => "" ,:email => "",:subject => "",:description => ""}
        flash[:notice] = Mailer.send_report_bug(report_bug)
      end
    else
      flash[:notice] = message
    end
    render :partial => 'report_bug_partial'
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
