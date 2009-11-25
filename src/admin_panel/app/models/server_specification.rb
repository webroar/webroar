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
class ServerSpecification
 
  class << self
    
    def validate_and_write(field, data)
      port, min_worker, max_worker, log_level, ssl_support, ssl_port, certificate, key, access_log = ServerSpecification.get_fields
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil      
      error_message = ''
      case field
      when 'port_div'
        if data =~ /^\d+$/ and data.to_i > 0 and data.to_i < 65535
          port = data.to_i
        else
          error_message = SERVER_PORT_VALIDATION
        end
        text = port
      when 'min_pro_div'
        if data =~ /^\d+$/ and data.to_i > 0 and data.to_i <= 20 and data.to_i <= info['Server Specification']['max_worker'].to_i
          min_worker = data.to_i
        else
          error_message = MINIMUM_WORKERS_VALIDATION
        end
        text = min_worker
      when 'max_pro_div'
        if data =~ /^\d+$/ and data.to_i > 0 and data.to_i <= 20 and data.to_i >= info['Server Specification']['min_worker'].to_i
          max_worker = data.to_i
        else
          error_message = MAXIMUM_WORKERS_VALIDATION
        end
        text = max_worker
      when 'ssl_port_div'
        if data =~ /^\d+$/ and data.to_i > 0 and data.to_i < 65535
          ssl_port = data.to_i
        else
          error_message = SSL_PORT_VALIDATION
        end
        text = ssl_port
      when 'certificate_div'
        if data.length > 0 and /^\/.*(\.crt)$/.match(data) and File.file?(data)
          certificate = data    
        else
          error_message = SSL_CERTIFICATE_FILE_PATH_VALIDATION1
        end
        text = certificate
      when 'key_div'
        if data.length > 0 and /^\/.*(\.key)$/.match(data) and File.file?(data)
          key = data
        else
          error_message = SSL_KEY_FILE_PATH_VALIDATION1
        end
        text = key
      when 'log_div'
        log_level = data
        text = log_level
      when 'access_log_div'
        access_log = data
        text = access_log
      end	
      if ssl_support.length < 1
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase]
      elsif ssl_support == "enabled"
        ssl_specification = Hash['ssl_support' => 'enabled', 'certificate_file' => certificate, 'key_file' => key, 'ssl_port' => ssl_port]
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase, 'SSL Specification' => ssl_specification]
      else
        ssl_specification = Hash['ssl_support' => 'disabled' , 'certificate_file' => certificate, 'key_file' => key, 'ssl_port' => ssl_port]
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase, 'SSL Specification' => ssl_specification]
      end
      ServerSpecification.write(info, server_specification) if error_message.length == 0
      return text, error_message
    end
    
    
    #Method is use to write server specification into the config file
    def write(info, server_specification)
      if info and info['Application Specification']
        application_specification = info['Application Specification']
        data = Hash['Server Specification' => server_specification, 'Application Specification' => application_specification]
      else
        data = Hash['Server Specification' => server_specification]
      end
      YAMLWriter.write(data,CONFIG_FILE_PATH, "config")
    end
  
    def get_fields
      info = YAML::load_file(CONFIG_FILE_PATH) rescue nil
      port = SERVER_PORT
      min_worker = MIN_WORKERS
      max_worker = MAX_WORKERS								
      log_level = LOG_LEVEL
      access_log = ACCESS_LOG
      ssl_support = ""
      ssl_port = ""
      certificate = ""
      key = ""
      if (info and info['Server Specification'])
        port = info['Server Specification']['port'].to_i if info['Server Specification']['port']
        min_worker = info['Server Specification']['min_worker'].to_i if info['Server Specification']['min_worker']
        max_worker = info['Server Specification']['max_worker'].to_i if info['Server Specification']['max_worker']
        log_level = info['Server Specification']['log_level'] if info['Server Specification']['log_level']
        access_log = info['Server Specification']['access_log'].capitalize if info['Server Specification']['access_log']
        if info['Server Specification']['SSL Specification']
          ssl_support = info['Server Specification']['SSL Specification']['ssl_support'] if info['Server Specification']['SSL Specification']['ssl_support']
          ssl_port = info['Server Specification']['SSL Specification']['ssl_port'] if info['Server Specification']['SSL Specification']['ssl_port']
          certificate = info['Server Specification']['SSL Specification']['certificate_file'] if info['Server Specification']['SSL Specification']['certificate_file']
          key = info['Server Specification']['SSL Specification']['key_file'] if info['Server Specification']['SSL Specification']['key_file']
        end
      end
      return port, min_worker, max_worker, log_level, ssl_support, ssl_port, certificate, key, access_log
    end
    
    def get_hash      
      port, min_worker, max_worker, log_level, ssl_support, ssl_port, certificate, key, access_log = get_fields
      
      if ssl_support.length < 1
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase]
      elsif ssl_support == "enabled"
        ssl_specification = Hash['ssl_support' => 'enabled' , 'certificate_file' => certificate, 'key_file' => key, 'ssl_port' => ssl_port]
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase, 'SSL Specification' => ssl_specification]
      else
        ssl_specification = Hash['ssl_support' => 'disabled', 'certificate_file' => certificate, 'key_file' => key, 'ssl_port' => ssl_port]
        server_specification = Hash['port' => port, 'min_worker' => min_worker, 'max_worker' => max_worker, 'log_level' => log_level, 'access_log' => access_log.downcase, 'SSL Specification' => ssl_specification]
      end      
      return server_specification
    end
  end
end
