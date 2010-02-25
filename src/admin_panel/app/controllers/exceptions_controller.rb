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
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, params[:page] || 1)
  end  
  
  #This method is to display the information of the specific exception.
  def show
    app_id = App.get_application_data(params[:app_name]).id
    @excep = AppException.get_exception_details_by_id(params[:id])
    @exceptions = AppException.get_exception_details_by_exception_message(@excep.exception_message, app_id)
    render :partial => 'show', :locals => { :status_name => params[:status_name], :app_name => params[:app_name], :page => params[:page] }
  end
  
  def show_exception_detail
    @excep = AppException.get_exception_details_by_id(params[:id])
    render :partial => 'exception_detail'
  end
  
  # This method is to display the list of exceptions as selection made from select box.
  def list
    @application_name = params[:application_name]
    session[:exceptions_application_name] = @application_name
    app_id = App.get_application_data(@application_name).id    
    @size = AppException.count_open(app_id)
    @exceptions = AppException.get_all(OPEN_EXCEPTION, app_id, params[:page] || 1)
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
    app_id = App.get_application_data(params[:app_name]).id
    @application_name = params[:app_name]
    status = get_status_const(params[:status_name])      
    @exceptions = AppException.get_all(status, app_id, params[:page] || 1)    
    render :update do |page|
      page.replace_html 'data_div', :partial => 'exception_list_partial', :locals => { :current_status => status, :status_name => params[:status_name] }      
    end 
  end
  
  #Method is used to update the status for selected exceptions.
  def change_status    
    if request.method == :put
      @application_name = params[:app_name]
      app_id = App.get_application_data(@application_name).id  
      if params[:exception_ids] and params[:status_name]        
        params[:exception_ids].collect! do |e|
          e.to_i
        end
        case params[:status_name].downcase
          when 'delete'
            
          when 'ignore'
            AppException.update_all_status_to(IGNORED_EXCEPTION, params[:exception_ids], app_id)
          when 'close'
            AppException.update_all_status_to(CLOSED_EXCEPTION, params[:exception_ids], app_id)
          when 'open'
            AppException.update_all_status_to(OPEN_EXCEPTION, params[:exception_ids], app_id)
        end
      end
      status = get_status_const(params[:current_status])
      @exceptions = AppException.get_all(status, app_id, params[:page])
      if @exceptions.out_of_bounds? and (page = params[:page].to_i - 1) > 0
        @exceptions = AppException.get_all(status, app_id, page)
      end
      render :update do |page|
        page.replace_html 'data_div', :partial => 'exception_list_partial', :locals => { :current_status => status, :status_name => params[:current_status]}  
      end
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
    end  
  end
end
