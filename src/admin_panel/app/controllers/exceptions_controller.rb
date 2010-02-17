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

#Controller class is used to handle all the views for exception handling feature.
class ExceptionsController < ApplicationController
  before_filter :login_required
  before_filter :clear_flash_notice
  before_filter :check_session_timeout, :except => ['get_exception']
  
  #the method is to render the index page of exception tab.
  #on this page the exception of the first application in the application array is deiplayed.
  def index
    @apps = get_application_list_for_exceptions
    session[:application_name] = get_application_list[0]
    if session[:exceptions_application_name].nil?
      app = @apps[0]
      session[:exceptions_application_name] = app
    else
      app = session[:exceptions_application_name]
    end  
    @application_name = app
    app_id = App.get_application_data(app).id rescue nil
    @start = 0    
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, @start)
  end  
  
  #This method is to display the information of the specific exception.
  def show
    app_id = App.get_application_data(params[:application_name]).id
    @excep = AppException.get_exception_details_by_id(params[:id])
    @exceptions = AppException.get_exception_details_by_exception_message(@excep.exception_message, app_id)
    render :partial => 'show'
  end
  
  # This method is to display the list of exceptions as selection made from select box.
  def list
    @application_name = params[:application_name]
    session[:exceptions_application_name] = @application_name
    app_id = App.get_application_data(@application_name).id
    @start = 0
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id)
    render :partial => 'exceptions_listing_partial'
  end
  
  #This methos is used to put the exception count on the home tab of the admin panel.
  def get_exception
    exceptions_count = App.exceptions_count(params[:app_name])  
    if  exceptions_count > 0
      link_text = "Yes (#{exceptions_count})"
      exception_span_data = link_text
    else
      exception_span_data = "No"
    end
    render :partial => 'link_partial', :locals => {:data => exception_span_data}
  end
  
  #Method sets the application name in the in the session and redirect it to the method index.
  def get_exceptions_list
    session[:exceptions_application_name] = params[:application_name]
    redirect_to :action => 'index'
  end
  
  #Method is used to list the exceptions with different status.
  def list_statuswise_exceptions
    if params[:status_name] == 'Ignored'
      ignored_exceptions(params[:app_name])
    elsif params[:status_name] == 'Closed'
      closed_exceptions(params[:app_name])
    else  
      opened_exceptions(params[:app_name])
    end
  end
  
  #Method is used to list all open exceptions for an application.
  def opened_exceptions(app_name)
    app_id = App.get_application_data(app_name).id
    @application_name = app_name
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, 0)
    render :partial => 'exception_list_partial', :locals => {:start => 0}
  end
  
  #Method is used to list all closed exceptions for an application.
  def closed_exceptions(app_name)
    app_id = App.get_application_data(app_name).id
    @application_name = app_name
    @size = AppException.count_closed(app_id)
    @exceptions = AppException.get_all(CLOSED_EXCEPTION, app_id, 0)
    render :partial => 'close_exception_list_partial', :locals => {:start => 0}
  end
  
  #Method is used to list all ignored exceptions for an application.
  def ignored_exceptions(app_name)
    app_id = App.get_application_data(app_name).id
    @application_name = app_name
    @size = AppException.count_ignored(app_id)
    @exceptions = AppException.get_all(IGNORED_EXCEPTION, app_id)
    render :partial => 'ignored_exception_list_partial', :locals => {:start => 0}
  end
  
  #Method is used to set the status for an exception as closed.
  def close_exception
    AppException.update_status_to(CLOSED_EXCEPTION, params[:app_name], params[:exception_name])    
    redirect_to :action => 'index'
  end
  
  #Method is used to set the status for an exception as ignored.
  def ignore_exception
    AppException.update_status_to(IGNORED_EXCEPTION, params[:app_name], params[:exception_name])    
    redirect_to :action => 'index'
  end
  
  #Method is used to set the status for an exception as reopened.  
  def reopen_exception
    AppException.update_status_to(OPEN_EXCEPTION, params[:app_name], params[:exception_name])    
    redirect_to :action => 'index'
  end
  
  #Gives the array of five open exceptions for pagination.
  def required_open_exceptions
    app_id = App.get_application_data(params[:app_name]).id
    @application_name = params[:app_name]
    @start = params[:start].to_i
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, @start)
    render :partial => 'exception_list_partial', :locals => {:start => @start}
  end
  
  #Gives the array of five closed exceptions for pagination.
  def required_closed_exceptions
    app_id = App.get_application_data(params[:app_name]).id
    @application_name = params[:app_name]
    @start = params[:start].to_i
    @size = AppException.count_closed(app_id)
    @exceptions = AppException.get_all(CLOSED_EXCEPTION, app_id, @start)
    render :partial => 'close_exception_list_partial', :locals => {:start => @start}
  end
  
  #Gives the array of five ignored exceptions for pagination.
  def required_ignored_exceptions
    app_id = App.get_application_data(params[:app_name]).id
    @application_name = params[:app_name]
    @start = params[:start].to_i
    @size = AppException.count_ignored(app_id)
    @exceptions = AppException.get_all(IGNORED_EXCEPTION, app_id, @start)
    render :partial => 'ignored_exception_list_partial', :locals => {:start => @start}
  end
end
