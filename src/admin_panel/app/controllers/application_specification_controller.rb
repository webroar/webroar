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

class ApplicationSpecificationController < ApplicationController
  before_filter :login_required #This method checks whether user is authenticated or not.
  before_filter :check_session_timeout  
  protect_from_forgery :only => [:add_application, :edit_application, :delete_application]
    
  #this action is to open a add application_specification form for adding a new application in the WebROaR config file.
  # This function also adds the default data to the application_specification form. 
  def add_application_form
    application_specification = ApplicationSpecification.get_hash
    @analytics = %w{Disabled Enabled}
    @application_specification = ApplicationSpecification.new(application_specification)
  end
  
  #This action is used to open a edit application specification details form.
  #This function retrives the values from the config file and then populate them in the edit application specification form.
  def edit_application_form
    application_name = params[:id]
    if !application_name.nil?
      application_id = ApplicationSpecification.get_application_id_from_name(application_name)
      application_specification = ApplicationSpecification.get_hash(application_id)
      @application_specification = ApplicationSpecification.new(application_specification)
      @analytics = %w{Disabled Enabled} if @application_specification.type1 == "Rails"
      @analytics = %w{Disabled} if @application_specification.type1 != "Rails"
    end			
  end
  
  #This action is to add the details of an application specification in the WebROaR config file.
  #The data for an application specification is supplied as a hash from a add application specification form.
  def add_application
    @application_specification = ApplicationSpecification.new(params[:application_specification])
    @analytics = %w{Disabled Enabled} if @application_specification.type1 == "Rails"
    @analytics = %w{Disabled} if @application_specification.type1 != "Rails"    
    if @application_specification.save
      @application_specification.write
      app_name = params[:application_specification][:name]
      reply, err_obj = App.start(app_name)
      # reply = nil indicate success
      if(err_obj)
        logger.warn err_obj
        logger.warn err_obj.backtrace
      end
      flash[:server_message] = "Application '#{app_name}' started successfully." if reply == nil
      flash[:error] = reply if reply
      render :js => "<script>self.top.location='#{configuration_path}'</script>"						
    else        
      render :partial => 'application_specification_form', :locals => {:type => 'Add'} 
    end
  end
  
  # This action is to delete the application specification from the WebROaR config file.
  #This method requires the id of the application specification to be deleted.
  def delete_application
    application_name = params[:id]
    application_id = ApplicationSpecification.get_application_id_from_name(application_name)
    app_name = ApplicationSpecification.delete(application_id)
    reply = App.stop(app_name)
    # reply = nil indicate success
    flash[:server_message] = "Application '#{app_name}' deleted successfully." if reply == nil
    flash[:error] = reply if reply
    render :js => "<script>self.top.location='#{configuration_path}'</script>"
  end
  
  #The action save the changes made in the application specification via edit application specification form.
  def edit_application
    @application_specification = ApplicationSpecification.new(params[:application_specification])
    @analytics = %w{Disabled Enabled} if @application_specification.type1 == "Rails"
    @analytics = %w{Disabled} if @application_specification.type1 != "Rails"        
    if @application_specification.save
      app_name = params[:id]
      application_id = ApplicationSpecification.get_application_id_from_name(app_name)
      @application_specification.update(application_id)      
      app_name = params[:application_specification][:name]
      reply = App.restart(app_name)
      # reply = nil indicate success
      flash[:server_message] = "Application '#{app_name}' restarted successfully." if reply == nil
      flash[:error] = reply if reply
      render :js => "<script>self.top.location='#{configuration_path}'</script>"
    else		  
      render :partial => 'application_specification_form', :locals => {:type => 'Edit'} 
    end
  end
  
  #This method is to restart the application.
  def restart_application
    sleep(2)
    info= YAML::load_file(CONFIG_FILE_PATH) rescue nil
    app_name = params[:id]
    reply = App.restart(app_name)
    # reply = nil indicate success
    flash[:server_message] = "Application '#{app_name}' restarted successfully." if reply == nil
    flash[:error] = reply if reply
    render :js => "<script>self.top.location='#{configuration_path}'</script>"
  end
  
  private
  #This method is used to create the obects of the apps class from the application specification hash.
  def create_apps_object(application)
    return ApplicationSpecification.new(application[:name], application[:baseuri], application[:path], application[:run_as_user], application[:type], 
      application[:analytics], application[:environment], application[:min_worker].to_i, application[:max_worker].to_i)
  end
end
