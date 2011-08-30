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
    flash[:notice] = params[:notice] if params[:notice]
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
    @size = AppException.count_open(app_id)
    session[:per_page] = 5 if not session[:per_page]
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, params[:page] || 1,session[:per_page])
  end  
  
  #This method is to display the information of the specific exception.
  def show    
    @exception = AppException.first(:conditions => ["id = ?", params[:id]]) # found include bug with eager loading, its fetching all the associated records     
    render :partial => 'show', :locals => { :status_name => params[:status_name], :app_name => params[:app_name], :page => params[:page] }
  end

  # This method is to show the backtrace of the exception
  def show_exception_backtrace
    @exception = AppException.first(:conditions => ["id = ?", params[:id]])
    render :partial => 'exception_backtrace_partial',:locals => {:index => params[:index].to_i,:status_name => params[:status_name], :app_name => params[:app_name], :page => params[:page] }
  end

  # This method is to show the environment details of the exception
  def show_exception_environment
    @exception = AppException.first(:conditions => ["id = ?", params[:id]])
    render :partial => 'exception_environment_partial',:locals => {:index => params[:index].to_i,:status_name => params[:status_name], :app_name => params[:app_name], :page => params[:page]}
  end

  # This method is to display the list of exceptions as selection made from select box.
  def list
    @application_name = params[:application_name]
    session[:exceptions_application_name] = @application_name
    app_id = App.get_application_data(@application_name).id    
    @size = AppException.count_open(app_id)
    session[:per_page] = 5 if not session[:per_page]
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, params[:page] || 1,session[:per_page])
    render :partial => 'exceptions_listing_partial'
  end
  
  #This method is used to put the exception count on the home tab of the admin panel.
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
    session[:per_page] = params[:per_page] if params[:per_page]     
    app_id = App.get_application_data(params[:app_name]).id
    @application_name = params[:app_name]
    status = get_status_const(params[:status_name])
    @exceptions = AppException.get_all(status, app_id, params[:page] || 1,session[:per_page])
    render :update do |page|
      page.replace_html 'data_div', :partial => 'exception_list_partial', :locals => { :current_status => status, :status_name => params[:status_name] }      
    end 
  end
  
  #Method is used to update the status for selected exceptions.
  def change_status    

    @application_name = params[:app_name]
    app_id = App.get_application_data(@application_name).id
    if params[:exception_ids] and params[:status_name]
      params[:exception_ids].collect! do |e|
        e.to_i
      end
      case params[:status_name].downcase
        when 'delete'

        when 'ignore'
          AppException.update_all_status_to(IGNORED_EXCEPTION, params[:exception_ids])
        when 'close'
          AppException.update_all_status_to(CLOSED_EXCEPTION, params[:exception_ids])
        when 'open'
          AppException.update_all_status_to(OPEN_EXCEPTION, params[:exception_ids])
      end
    end
    status = get_status_const(params[:current_status])
    session[:per_page] = 5 if not session[:per_page]
    @exceptions = AppException.get_all(status, app_id, params[:page],session[:per_page])
    if @exceptions.out_of_bounds? and (page = params[:page].to_i - 1) > 0
      @exceptions = AppException.get_all(status, app_id, page,session[:per_page])
    end
    render :update do |page|
      page.replace_html 'data_div', :partial => 'exception_list_partial', :locals => { :current_status => status, :status_name => params[:current_status]}  
    end
  end

  # This method is used to render the add_application_class_form partial with all the exception classes
  # stored in configuration file, with respect to the selected application
  def save_exception_class_form
    if params[:app_name]
      @exception_classes = AppException.get_exception_classes(params[:app_name])
      render :partial => "add_exception_class_form" , :locals =>{:app_name => params[:app_name]}
    else
      error = "You have been redircted, because application name was missing"
      redirect_to :action => 'index' ,:notice => error
    end
  end

  # This method is used to fetch the app_id and exception_class from user and
  # call the add_exception_class_in_config_file method to save the exception classes
  def save_exception_class
    if params[:app_name]
      flash[:notice] = AppException.add_exception_class(params[:app_name],params[:exception][:class])
      @exception_classes = AppException.get_exception_classes(params[:app_name])
      render :partial => 'add_and_list_exception_classes', :locals => {:app_name => params[:app_name]}
    else
      error = "You have been redircted, because application name was missing"
      redirect_to :action => 'index' ,:notice => error
    end
  end

  # This method is used to remove the exception classes from configuration file
  def delete_exception_class
    if params[:app_name] and params[:exception_class]
      @exception_classes = AppException.delete_exception_class_from_config(params[:app_name],params[:exception_class])
      render :partial => 'add_and_list_exception_classes', :locals => {:app_name => params[:app_name]}
    else
      error = "You have been redircted, because application name and exception class were missing"
      redirect_to :action => 'index' ,:notice => error
    end
  end

private
  def get_status_const(status_name)
    case status_name.downcase
      when 'open'
        status = OPEN_EXCEPTION
      when 'closed', 'close'
        status = CLOSED_EXCEPTION
      when 'ignored', 'ignore'
        status = IGNORED_EXCEPTION
      when 'permanently-ignored', 'permanently-ignore'
        status = PERMANENTLY_IGNORED_EXCEPTION
    end
  end
end
