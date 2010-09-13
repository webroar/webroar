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
  has_many :exception_details, :order => 'wall_time DESC'
  has_many :occurrences, :select =>"id, app_exception_id, wall_time", :class_name => "ExceptionDetail", :order => 'wall_time DESC'
  has_one :latest_detail, :class_name => "ExceptionDetail", :order => 'wall_time DESC'
  class << self
    #Gives the array of the five (open|closed|ignored) exceptions starting from the value of varriable 'start' for an application.
    def get_all(exception_status, app_id, page = 1, per_page = 5)
      paginate(:conditions => ['app_id = ?  and exception_status = ?', app_id, exception_status],
#               :include => [:latest_detail], # found bug with eager loading, its fetching all the associated records              
               :page => page, :per_page => per_page)
    end
    
    # Take App.id as argument and returns count of distinct open exceptions for an Application
    def count_open(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => OPEN_EXCEPTION})
    end
    
    # Take App.id as argument and returns count of distinct closed exceptions for an Application
    def count_closed(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => CLOSED_EXCEPTION})
    end
    
    # Take App.id as argument and returns count of distinct ignored exceptions for an Application
    def count_ignored(app_id)
      count(:exception_message, :conditions => {:app_id => app_id, :exception_status => IGNORED_EXCEPTION})
    end
    
    # Update all exceptions status for given exceptions id array
    def update_all_status_to(status, exceptions_id_array)
      update_all(["exception_status = ?",status], ["id in (#{exceptions_id_array.join(',')})"])      
    end
  end
end
