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

class ServerSpecificationController < ApplicationController
  before_filter :login_required
  before_filter :check_session_timeout
  
  #This method is used to disable the ssl support.
  def disable_ssl_support
    info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
    ssl_specification = Hash['ssl_support' => 'disabled',
      'certificate_file' => info['Server Specification']['SSL Specification']['certificate'],
      'key_file' => info['Server Specification']['SSL Specification']['key'],
      'ssl_port' => info['Server Specification']['SSL Specification']['port']]
    server_specification = Hash['port' => info['Server Specification']['port'],
      'log_level' => info['Server Specification']['log_level'],
      'min_worker' => info['Server Specification']['min_worker'],
      'max_worker' => info['Server Specification']['max_worker'],
      'access_log' => info['Server Specification']['access_log'],
      'SSL Specification' => ssl_specification]
    ServerSpecification.write(info, server_specification)
    redirect_to configuration_path
  end
  
  #This method is used to enable the ssl support.
  def enable_ssl_support
    info= YAML::load_file(CONFIG_FILE_PATH) rescue nil
    str = check_for_ssl_validation(params[:ssl])
    if str.length == 0
      ssl_specification = Hash['ssl_support' => 'enabled',
        'certificate_file' => params[:ssl][:certificate_path],
        'key_file' => params[:ssl][:key_path],
        'ssl_port' => params[:ssl][:port]]
      server_specification = Hash['port' => info['Server Specification']['port'],
        'log_level' => info['Server Specification']['log_level'],
        'min_worker' => info['Server Specification']['min_worker'],
        'max_worker' => info['Server Specification']['max_worker'],
        'access_log' => info['Server Specification']['access_log'],
        'SSL Specification' => ssl_specification]
      ServerSpecification.write(info, server_specification)
      flash[:error] = RESTART_SERVER_MESSAGE
      redirect_to configuration_path
    else
      flash[:ssl_errors] = str  
      redirect_to :controller => 'admin', :action=>'configuration', :ssl => params[:ssl]
    end
  end
 
  #This method is to render ssl_support_form partial
  def ssl_support_form
    @ssl_spec = Hash[:certificate_path => "", :key_path => "", :port => 443]
    render :partial => 'ssl_support_form'
  end
  
  #This function is to add server specification.
  #This action is used to save the changes made through configuration page.	  
  def save_data
    text = params[:old_value].to_s    
    if !params[:data][:value].empty?
      text, error_message = ServerSpecification.validate_and_write( params[:div_id], params[:data][:value])
      if error_message.length > 0
        render :text => 	text.to_s + " <span id='error_div'>#{error_message}</span>"
      else
        render :text => 	text.to_s + " <span id='error_div'>#{RESTART_SERVER_MESSAGE}</span>"
      end
    end
  end
  
  private
  
  #Method is to check for the various constarins for ssl supports 
  def check_for_ssl_validation(ssl)
    str = ""
    if ssl[:port] =~ /^\d+$/ and  ssl[:port].to_i < 1 and  ssl[:port].to_i > 65535
      str += "<li>#{SSL_PORT_VALIDATION}</li>" 
    end
    if ssl[:certificate_path].length <= 0
      str += "<li>#{SSL_CERTIFICATE_FILE_PATH_VALIDATION1}</li>"    
    elsif !File.file?(ssl[:certificate_path])
      str += "<li>#{SSL_CERTIFICATE_FILE_PATH_VALIDATION3}</li>"
    end
    if ssl[:key_path].length <= 0
      str += "<li>#{SSL_KEY_FILE_PATH_VALIDATION1}</li>"    
    elsif !File.file?(ssl[:key_path])
      str += "<li>#{SSL_KEY_FILE_PATH_VALIDATION3}</li>"
    end
    return str
  end
end
