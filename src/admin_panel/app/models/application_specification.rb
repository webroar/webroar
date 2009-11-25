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

class ApplicationSpecification < PseudoModel
  column :app_id,       :string
  column :name,         :string
  column :host_names,   :string
  column :baseuri,      :string
  column :resolver,     :string
  column :path,         :string
  column :run_as_user,  :string
  column :type1,        :string
  column :analytics,    :string
  column :environment,  :string
  column :min_worker, :number
  column :max_worker, :number
  validates_presence_of :name, :resolver, :path, :run_as_user, :type1, :environment
  validates_numericality_of :min_worker, :max_worker, :greater_than_or_equal_to => 1, :less_than_or_equal_to => 20
  validates_format_of :name, :with => /^[A-Za-z0-9_\-]*$/i, :message => " must consist of A-Z, a-z, 0-9 , _ , -  and /."
#  validates_format_of :path, :with => /^\/.*$/i, :message => "entered is not the complete path for your web application root directory."
  validates_length_of :name, :maximum => 30
  #validates_length_of :path, :maximum => 256
  validates_length_of :run_as_user, :maximum => 30  
  validates_length_of :environment, :maximum => 30
  #  validates_format_of :baseuri, :with => /^\/[A-Za-z0-9_\-\/]*$/i, :message => "must start with '/' and contains characters A-Z, a-z, 0-9 , _ , -  and /."

  def write
    server_specification = ServerSpecification.get_hash
    info= YAML::load_file(CONFIG_FILE_PATH) rescue nil
    if info 
      if info['Application Specification']
        i = info['Application Specification'].size
        info['Application Specification'][i] = obj_to_hash
        data = info['Application Specification']
      else
        data = Array[obj_to_hash]
      end
    else
      data = Array[obj_to_hash]
    end
    info = Hash['Server Specification' => server_specification, 'Application Specification' => data]
    YAMLWriter.write(info, CONFIG_FILE_PATH, "config")
  end
    
  #Converting ApplicationSpecification obeject into a Hash.
  def obj_to_hash
    app = Hash["name" => name, "path" => path, "run_as_user" => run_as_user.downcase, "type" => type1.downcase, "analytics" => analytics.to_s.downcase, "environment" => environment.downcase, "min_worker" => min_worker.to_i, "max_worker" => max_worker.to_i]
    app["baseuri"] = baseuri.strip if baseuri
    app["host_names"] = host_names if host_names
    return app
  end
  
  def update(app_id)
    info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
    info['Application Specification'][app_id] = obj_to_hash	
    YAMLWriter.write(info, CONFIG_FILE_PATH, "config")
  end
  
  #this method is used to validate the various fields of the apps model.
  def validate     
#    errors.add_to_base MIN_WORKERS_VALIDATION if min_worker.to_i > 20
    if max_worker.to_i < min_worker.to_i
      errors.add_to_base MAX_WORKERS_VALIDATION_1
#    elsif max_worker.to_i > 20
#      errors.add_to_base MAX_WORKERS_VALIDATION_2
    end
#    errors.add_to_base APPLICATION_PATH_EXISTANCE_VALIDATION if !File.directory?(path)
    errors.add_to_base ANALYTICS_VALIDATION if type1=="Rails" and !(analytics.downcase == "enabled" or analytics.downcase == "disabled")
    #errors.add_to_base ENVIRONMENT_VALIDATION if !(environment.downcase == "production" or environment.downcase == "development" or environment.downcase == "test")
    errors.add_to_base TYPE_VALIDATION if !(type1.downcase == RAILS or type1.downcase == RACK)
    if path and type1
      if type1.downcase == RAILS
        unless File.exists?(File.join(path, 'config', 'environment.rb'))
          errors.add_to_base "The entered application path is not a valid Rails application path."
        end
      end
      if type1.downcase == RACK
        unless File.exists?(File.join(path, 'config.ru'))
          errors.add_to_base "The entered application path is not a valid Rack application path."
        end
      end      
    end  
    # Resolver take either baseuri or host_names, not both. 
    # baseuri starts with '/'      
    tokens = resolver.split(/ /)
      
    curr_host_names = []
    host_names_flag = 0
    if tokens.size == 1 and tokens[0].start_with?('/')
      write_attribute(:baseuri, resolver)
      errors.add_to_base "BaseURI must start with '/' and contains characters A-Z, a-z, 0-9 , _ , -  and /." if !(baseuri.strip =~ /^\/[A-Za-z0-9_\-\/]*$/i)
    else
      write_attribute(:host_names, resolver)
      host_name_flag = 1
    end
    # More than one token would come only in case of host_names
    if host_name_flag == 1 and tokens.size > 0
      tokens.each do |token|
        next if token == ""
        len = token.size
        # Whole name can not exceed total length of 253
        if len > 253
          errors.add_to_base HOSTNAME_LENGTH_EXCEEDS
          next
        end          
        # Subdivision can go down to maximum 127 level.
        labels = token.split(/\./)
        if labels.size > 127
          errors.add_to_base SUBDIVISION_EXCEEDS_127
          next
        end
        # Start with '/' indicates BaseURI
        if token.start_with?('/')
          errors.add_to_base BASEURI_AND_HOSTNAMES_EXIST
          break
        end
        # If wildcard '*' presents, Hostname should prefix with '~'
        if token.include?("*") and !(token =~ /^~/)
          errors.add_to_base "#{token} - #{START_WTIH_TILD}"   
          next         
        end
        # Wildcard '*' can come either at start or at end, not inbetween
        pos = token.index('*', 1)
        if pos and pos != 1 and pos != len-1
          errors.add_to_base "#{token} - #{WILDCARD_AT_START_OR_END}"
          next
        end
        pos = token.index('*', 2)
        if pos and pos != len - 1
          errors.add_to_base "#{token} - #{WILDCARD_AT_START_OR_END}"
          next
        end
        if token =~ /[.][.]/
          errors.add_to_base "#{token} - #{CONSECUTIVE_DOTS}"
          next
        end
        # Check for Letters, Digits and Hyphen
        err_flag = 0
        #first label can have '~' as first char and '*' as second char, last label can have '*' as last character
        first_label = labels[0]              
        last_label = labels[labels.size - 1]
        labels = labels[1..labels.size - 2]
        labels.each do |label|
          if label.size > 63
            errors.add_to_base LABEL_LENGTH_EXCEEDS
            next
          end
          label.each_char do |c|
            if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' 
              next
            else
              errors.add_to_base HOSTNAME_LDH 
              err_flag = 1
              break;
            end
          end
        end
        char_array = []
        first_label.each_char do |c|
          char_array << c
        end
        #p char_array
        # checking first character of first label against LDH and ~
        if err_flag == 0            
          c = char_array[0]
          if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '~'             
          else
            errors.add_to_base HOSTNAME_LDH
            err_flag = 1
          end
        end
        #checking second char of first label against LDH and *
        if err_flag == 0
          c = char_array[1]
          if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '*'             
          else
            errors.add_to_base HOSTNAME_LDH
            err_flag = 1
          end
        end
        #checking remaining character of first label against LDH
        char_array = char_array[2..char_array.size - 1]
        if err_flag == 0
          char_array.each do |c| 
            if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' 
              next
            else
              errors.add_to_base HOSTNAME_LDH 
              err_flag = 1
              break;
            end
          end            
        end
        #checking last character of last label against LDH and *
        char_array = []
        last_label.each_char do |c|
          char_array << c
        end
        if err_flag == 0
          c = char_array[char_array.size - 1]
          if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '*'             
          else
            errors.add_to_base HOSTNAME_LDH
            err_flag = 1
          end
        end
        #checking remaining characters of the last label against LDH
        if err_flag == 0
          char_array = char_array[1..char_array.size - 2]
          char_array.each do |c|
            if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '*'             
            else
              errors.add_to_base HOSTNAME_LDH
              err_flag = 1
            end
          end            
        end
        if err_flag == 0
          curr_host_names << token
        end
      end
    end
    
    #BaseURI can not be /admin-panel
    errors.add_to_base BASEURI_AS_ADMIN_PANEL_BASEURI_VALIDATION if baseuri and baseuri.strip == ADMIN_PANEL_BASE_URI
    all_host_names = []
    curr_host_names_size = curr_host_names.size
      
    #checking uniqueness of BaseURI
    info= YAML::load_file(CONFIG_FILE_PATH)
    if info and info['Application Specification']
      i = 0
      flag = 0
      while(info['Application Specification'][i])
        flag = 1 if baseuri and baseuri.strip and info['Application Specification'][i]['baseuri'] == baseuri.strip and app_id.to_i != i.to_i
        errors.add_to_base "#{name} - #{APPLICATION_NAME_REPEATED}" if info['Application Specification'][i]['name'] == name and app_id.to_i != i.to_i
        all_host_names << info['Application Specification'][i]['host_names'].split(/ /) if info['Application Specification'][i]['host_names'] and curr_host_names_size > 0 and app_id.to_i != i.to_i
        i += 1
      end        
      errors.add_to_base BASEURI_EXISTANCE_VALIDATION if flag == 1
    end
    all_host_names.flatten!
    # checking uniqueness of Hostnames
    if curr_host_names_size > 0
      errors.add_to_base HOSTNAME_REPEATED  if curr_host_names_size != curr_host_names.uniq.size
      if all_host_names.size > 0
        curr_host_names.each do |c_host_name|
          all_host_names.each do |host_name|
            if c_host_name.eql?(host_name)
              errors.add_to_base "#{c_host_name}-#{HOSTNAME_REPEATED }"
              break
            end
          end
        end
      end
    end      
  end
 
  class << self
    def delete(app_id)
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      app_name = info['Application Specification'][app_id]["name"]
      info['Application Specification'].delete_at(app_id)
      if(info['Application Specification'].length == 0)
        info.delete('Application Specification')
      end	
      YAMLWriter.write(info,CONFIG_FILE_PATH,"config")
      return app_name
    end
    
    #This method is to get application specifications for a specific application from WebROaR config file.
    def get_hash(application_id = 1000)
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      name = ""    
      path = ""
      run_as_user = ""
      type = "Rails"
      analytics = "Disabled"
      environment = "Production"
      port, min_worker, max_worker, log_level = ServerSpecification.get_fields
      if !application_id.nil?
        if info and info['Application Specification'] and info['Application Specification'][application_id] 
          name = info['Application Specification'][application_id]['name'] if info['Application Specification'][application_id]['name']
          baseuri = info['Application Specification'][application_id]['baseuri'] if info['Application Specification'][application_id]['baseuri']	
          host_names = info['Application Specification'][application_id]['host_names'] if info['Application Specification'][application_id]['host_names']	
          path = info['Application Specification'][application_id]['path'] if info['Application Specification'][application_id]['path']	
          run_as_user = info['Application Specification'][application_id]['run_as_user'] if info['Application Specification'][application_id]['run_as_user']	
          type = info['Application Specification'][application_id]['type'].capitalize if info['Application Specification'][application_id]['type']
          analytics = info['Application Specification'][application_id]['analytics'].capitalize if info['Application Specification'][application_id]['analytics']
          environment = info['Application Specification'][application_id]['environment'].capitalize if info['Application Specification'][application_id]['environment']
          min_worker = info['Application Specification'][application_id]['min_worker'] if info['Application Specification'][application_id]['min_worker']
          max_worker = info['Application Specification'][application_id]['max_worker'] if info['Application Specification'][application_id]['max_worker']
        end
      end
      app_hash = Hash[:app_id => application_id.to_i, 
        :name => name,                
        :path => path,
        :run_as_user => run_as_user,
        :type1 => type,
        :analytics => analytics,
        :environment => environment,
        :min_worker => min_worker,
        :max_worker => max_worker]
      app_hash[:resolver] = baseuri if baseuri
      app_hash[:resolver] = host_names if host_names

      return app_hash  
    end

    def get_application_id_from_name(application_name)
        info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
        i = 0 
        while info['Application Specification']
          if info['Application Specification'][i]['name'] == application_name
            break
          end
          i +=1
        end  
        return i
    end  
  end
end
