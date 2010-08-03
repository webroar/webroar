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

class Headers < PseudoModel
  class << self
    
    def get_expires_value
      @conf = YAML::load_file(CONFIG_FILE_PATH)
      if @conf['Headers'] and @conf['Headers']['expires']
        @conf['Headers']['expires']
      else
        "Off"
      end
    end
    
    def get_expires_by_type_array
      @conf = YAML::load_file(CONFIG_FILE_PATH)     
      return @conf['Headers']['expires_by_type'] if @conf['Headers'] and @conf['Headers']['expires_by_type'] and @conf['Headers']['expires_by_type'].length > 0
      []
    end
    
    def delete_expires_by_type(index)
      @conf = YAML::load_file(CONFIG_FILE_PATH)
      if @conf['Headers'] and @conf['Headers']['expires_by_type']
        @conf['Headers']['expires_by_type'].delete_at(index)
      end
      @conf['Headers'].delete('expires_by_type') if @conf['Headers']['expires_by_type'].empty?
      @conf.delete('Headers') if @conf['Headers'].empty?
      YAMLWriter.write(@conf, CONFIG_FILE_PATH, YAMLConfig::CONFIG) 
    end
    
    def validate_and_write_expires_value(old_value, data)
      expires = old_value
      error_message = ""
      data = data.strip
      if data.empty?
        error_message = EMPTY_STRING
        return expires, error_message
      end      
      
      if data.to_s.downcase == 'off'
        expires = 'Off'
        write_expires_value("Off")
      elsif data =~ /^\d+$/ and data.to_i > 0
        expires = data.to_i
        write_expires_value(expires)        
      else
        error_message = EXPIRES_VALIDATION        
      end
      return expires, error_message
    end
    
    def validate_and_write_expires_by_type(ext, expires)
      ext = ext.strip
      expires = expires.strip
      err_msg = nil
      if ext.empty?
        err_msg = "<ul>"
        err_msg += "<li>File extensions can not be empty.</li>"
      end
      if expires.empty?
        err_msg += "<li>Expires value can not be empty</li>"
      end
      unless expires =~ /^\d+$/ and expires.to_i > 0
        err_msg += "<li>Possible value for expires is no. of seconds</li>"
      end
      if err_msg
        err_msg += "</ul>"
        return err_msg
      end
      write_expires_by_type_value(ext, expires.to_i)
      return ''
    end
    
    def write_expires_by_type_value(ext, expires)
      @conf = YAML::load_file(CONFIG_FILE_PATH)
      @conf['Headers'] = Hash.new unless @conf['Headers']
      @conf['Headers']['expires_by_type'] = Array.new unless @conf['Headers']['expires_by_type']
      @conf['Headers']['expires_by_type'].push(Hash['ext' => ext, 'expires' => expires])
      YAMLWriter.write(@conf, CONFIG_FILE_PATH, YAMLConfig::CONFIG)
    end
    
    def write_expires_value(expires)
      @conf = YAML::load_file(CONFIG_FILE_PATH)
      if expires.to_s.downcase == 'off'        
        if @conf['Headers'] and @conf['Headers']['expires']
          @conf['Headers'].delete('expires')
          @conf.delete('Headers') if @conf['Headers'].empty?
        end
      else
        @conf['Headers'] = Hash.new unless @conf['Headers']
        @conf['Headers']['expires'] = expires
      end
            
      YAMLWriter.write(@conf, CONFIG_FILE_PATH, YAMLConfig::CONFIG)      
    end
    
  end  
end