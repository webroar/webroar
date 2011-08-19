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

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'digest/md5'
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery #:secret => '8e99f4efee54d3b72e3b675578e1403c'
  #  before_filter :check_timeout
  include SslRequirement if SSL_ON
private  
  # This method is used for the user authentication in the login process.
  def user_authentication(loggedin_user)
    users = YAML::load_file(USERS_FILE_PATH)
    user_found = false
    return false unless (loggedin_user[:name] or loggedin_user[:password])
    users.each do |user|
      if(loggedin_user[:name] == user['user_name'] && Digest::MD5.hexdigest(loggedin_user[:password]) == user['password'])
        user_found = true
        session[:user] = loggedin_user[:name]
        break
      end
    end
    return(user_found)
  end
  
  #This method is used to check the authentic user for the application.
  #This method is called whenever user try to access any of the application's link.
  def login_required
    response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate,max-age = 0, pre-check = 0, post-check = 0'  
    if session[:user].nil?     
      session[:referer] = request.request_uri
      flash[:notice] = SESSION_EXPIRE_MESSAGE
      if request.xhr?()
        render :text => "<script type='text/javascript'>self.top.location='#{PREFIX}';</script>"
      else
        redirect_to root_path
      end
    else
      return true
    end
  end
  
  #This method is to add time bound session timeout.
  def check_session_timeout
    if session[:session_time]
      if Time.now-session[:session_time] > 15.minutes
        reset_session
        session[:session_time] = Time.now
        flash[:notice] = SESSION_EXPIRE_MESSAGE
        if request.xhr?()
          render :text => "<script type='text/javascript'>self.top.location='#{PREFIX}';</script>"
        else
          redirect_to root_path
        end
      else
        session[:session_time] = Time.now
      end
    else
      session[:session_time] = Time.now
    end
    
  end
  
  #This method is used to clear the flash notice messages before navigating to another action.
  def clear_flash_notice
    flash[:notice] = nil
  end
   
  #This method returns the array of applications if WebROaR config file contains Application specification.
  def get_application_list #This method returns the array if the application present in config file
    i = 0	
    apps = Array.new	
    info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
    if info and info['Application Specification']	
      while(info['Application Specification'][i])
        #if info['Application Specification'][i]['analytics'].downcase == "enabled".downcase
          apps << info['Application Specification'][i]['name'].gsub("<","&lt;").gsub(">","&gt;")
        #end	
        i += 1
      end	
    end
    apps << SERVER_NAME
    if session[:application_name].nil?
      session[:application_name] = apps[0]
      @application_name = apps[0]
    else
      @application_name = session[:application_name]
    end
    return apps
  end
  
  #This method returns the array of the application present in config file
  def get_application_list_for_exceptions 
    i = 0	
    apps = Array.new	
    info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
    if info and info['Application Specification']	
      while(info['Application Specification'][i])
        if info['Application Specification'][i]['type'].downcase == 'rails'
          apps << info['Application Specification'][i]['name'].gsub("<","&lt;").gsub(">","&gt;")
        end
        i += 1
      end	
    end
    return apps
  end
end
