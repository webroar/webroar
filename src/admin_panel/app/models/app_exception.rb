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

#Model class for App Exceptions. This model helps to show the details of the exceptions tracked by the server.
class AppException < ActiveRecord::Base
  class << self
    #Gives the array of the five (open|closed|ignored) exceptions starting from the value of varriable 'start' for an application.
    def get_all(exception_status, app_id, start = 0)
      all(:select => 'id, exception_message, exception_class, controller, method, wall_time, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, exception_status], :group => 'exception_message', :limit => "#{start}, 5", :order => 'wall_time desc')
    end
    
    # Take App.id as argument and returns count of distinct open exceptions for an Application
    def count_open(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => OPEN_EXCEPTION}, :distinct => true)
    end
    
    # Take App.id as argument and returns count of distinct closed exceptions for an Application
    def count_closed(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => CLOSED_EXCEPTION}, :distinct => true)
    end
    
    # Take App.id as argument and returns count of distinct ignored exceptions for an Application
    def count_ignored(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => IGNORED_EXCEPTION}, :distinct => true)
    end

    # Update all exceptions status for a matching application and exception message  
    def update_status_to(status, app_name, exception_message)
      if app = App.first(:select => 'id', :conditions => {:name => app_name})
        app_id = app.id
        exceptions_id_array = all(:select =>'id', :conditions => ["exception_message = ? and app_id  = ?", exception_message, app_id]).collect { |e| e.id } 
        update_all(["exception_status = ?",status], ["id in (#{exceptions_id_array.join(',')})"])
      end
    end
    
    #Gives the details of the exception with some specific id.
    def get_exception_details_by_id(exception_id)
      exception = find(:first, :conditions => ["id = ?", exception_id])
      return exception
    end 
    
    #Gives the details af an exception with the help of its exception_message for a specific application.
    def get_exception_details_by_exception_message(exception_message, app_id)
      exception = find(:all, :conditions => ["exception_message = ? and app_id  = ?", exception_message, app_id], :order => 'wall_time desc')
      return exception
    end
  end
end
