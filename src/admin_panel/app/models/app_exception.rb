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
  belongs_to :app
  has_many :exception_details, :order => 'wall_time DESC', :dependent => :destroy  
  has_many :occurrences, :select =>"id, app_exception_id, wall_time", :class_name => "ExceptionDetail", :order => 'wall_time DESC'
  has_one :latest_detail, :class_name => "ExceptionDetail", :order => 'wall_time DESC'
  class << self
    #Gives the array of the five (open|closed|ignored) exceptions starting from the value of varriable 'start' for an application.
    def get_all(exception_status, app_id, page = 1, per_page = 5)
      where(:app_id => app_id, 
            :exception_status => exception_status
            ).paginate(:page => page, 
            :per_page => per_page)
    end
    
    # Take App.id as argument and returns count of distinct open exceptions for an Application
    def count_open(app_id)
      where(:app_id => app_id, :exception_status => OPEN_EXCEPTION).count
    end
    
    # Take App.id as argument and returns count of distinct closed exceptions for an Application
    def count_closed(app_id)
      where(:app_id => app_id, :exception_status => CLOSED_EXCEPTION).count
    end
    
    # Take App.id as argument and returns count of distinct ignored exceptions for an Application
    def count_ignored(app_id)
      where(:app_id => app_id, :exception_status => IGNORED_EXCEPTION).count
    end
    
    # Update all exceptions status for given exceptions id array
    def update_all_status_to(status, exceptions_id_array)
      update_all(["exception_status = ?",status], ["id in (#{exceptions_id_array.join(',')})"])      
    end

    # This method is used to check the existance of exception class
    # and call save_exception_class_in_config_file method
    def add_exception_class(app_name,exception_class)
      if exception_class != ""
        save_exception_class_in_config_file(app_name,exception_class)
      else
        "can't be blank."
      end
    end

    # This method is used to add the exception classes into configuration file
    def save_exception_class_in_config_file(app_name,exception_class)
      app_id = ApplicationSpecification.get_application_id_from_name(app_name)
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      info['Application Specification'][app_id]['permanently_ignored_list'] = Array.new if not info['Application Specification'][app_id]['permanently_ignored_list']
      if not info['Application Specification'][app_id]['permanently_ignored_list'].include?(exception_class)
        info['Application Specification'][app_id]['permanently_ignored_list'].push(exception_class)
        YAMLWriter.write(info, CONFIG_FILE_PATH, YAMLConfig::CONFIG)
        update_all_status_by_exception_class(app_name,exception_class,PERMANENTLY_IGNORED_EXCEPTION)
        return
      end
      "Exception class already exist."
    end

    # This method is used to delete the exception classes from configuration file
    def delete_exception_class_from_config(app_name,exception_class)
      app_id = ApplicationSpecification.get_application_id_from_name(app_name)
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      info['Application Specification'][app_id]['permanently_ignored_list'].delete(exception_class)
      YAMLWriter.write(info, CONFIG_FILE_PATH, YAMLConfig::CONFIG)
      update_all_status_by_exception_class(app_name,exception_class,OPEN_EXCEPTION)
      exception_classes = info['Application Specification'][app_id]['permanently_ignored_list']
    end

    # This method is used to get all the exception classes from configuration file for the given app_id
    def get_exception_classes(app_name)
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      app_data = info['Application Specification'].detect{|app_item| app_item["name"].eql?(app_name)}
      if not app_data['permanently_ignored_list']
        exception_classes = Array.new
      else
        exception_classes = app_data['permanently_ignored_list']
      end
    end

    # TODO Change function to fetch all exception records if we require all exception fields instead of id only  
    def get_exceptions_by_class(app_id,exception_class)
      where(:app_id => app_id, :exception_class => exception_class).select(:id)
    end

    # This method is used to change status of exceptions by searching the exception with exception_class
    def update_all_status_by_exception_class(app_name,exception_class,status)
      app_id = App.get_application_data(app_name).id
      app_id_array = get_exceptions_by_class(app_id,exception_class)
      app_ids = app_id_array.collect { |a| a['id']}
      update_all_status_to(status,app_ids)
    end

    # This function is used to fetch the first exception record for the given exception_message pattern ,
    # exception_class, exception_details.controller , exception_details.method and app_id
    def get_exception_for_analyzer(exception_hash, app_id)
      where("exception_message like ? and exception_class = ? and controller = ? and method = ? and app_id = ?",
                          exception_hash[:exception_message].split(EXCEPTION_MESSAGE_SPLITER)[0] + '%',
                          exception_hash[:exception_class],
                          exception_hash[:controller],
                          exception_hash[:method],
                          app_id).first
    end
  end
end
