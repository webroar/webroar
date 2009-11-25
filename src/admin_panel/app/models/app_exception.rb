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
    #Gives the array of the five open exceptions starting from the value of varriable 'start' for an application.
    def get_open_exceptions(app_id, start = 0)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 1], :group => 'exception_message', :limit => "#{start}, 5", :order => 'wall_time desc')
      return exceptions
    end
    
    #Gives the array of the all open exceptions for an application.
    def get_all_open_exceptions(app_id)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 1], :group => 'exception_message', :order => 'wall_time desc')
      return exceptions
    end
    
    #Gives the array of the all closed exceptions for an application.
    def get_all_closed_exceptions(app_id)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 0], :group => 'exception_message', :order => 'wall_time desc')
      return exceptions
    end
    
    #Gives the array of the closed exceptions starting from the value of varriable 'start' for an application.
    def get_closed_exceptions(app_id, start = 0)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 0], :group => 'exception_message', :limit => "#{start}, 5", :order => 'wall_time desc')
      return exceptions
    end
    
    #Gives the array of the ignored exceptions starting from the value of varriable 'start' for an application.
    def get_ignored_exceptions(app_id, start = 0)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 2], :group => 'exception_message' , :limit => "#{start},5" , :order => 'wall_time desc')
      return exceptions
    end
    
    #Gives the array of the all ignored exceptions for an application.
    def get_all_ignored_exceptions(app_id)
      exceptions = find(:all, :select => '*, count(*) as count', :conditions => ['app_id = ?  and exception_status = ?', app_id, 2], :group => 'exception_message', :order => 'wall_time desc')
      return exceptions
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
