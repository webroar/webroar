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

#Client class based on ebb server's http://github.com/ry/ebb/tree/v0.1.0

module Webroar
  class Client
    BASE_ENV = {
      SERVER_NAME => WEBROAR,
      SCRIPT_NAME => EMPTY_STRING,
      QUERY_STRING => EMPTY_STRING,
      SERVER_SOFTWARE => Webroar::SERVER,
      SERVER_PROTOCOL => HTTP_1_1,
      RACK_VERSION => [0, 1],
      RACK_ERRORS => STDERR,
      RACK_URL_SCHEME => HTTP,
      RACK_MULTIPROCESS => false,
      RACK_RUN_ONCE => false
    }
    
    def env
      #puts "in env "
      env = Webroar::client_env(self).update(BASE_ENV)
      env[HTTP_HOST] ||= BASE_ENV[SERVER_NAME]
      env[RACK_INPUT] = RequestBody.new(self)
      env[CONTENT_TYPE] = env.delete(HTTP_CONTENT_TYPE) if env[HTTP_CONTENT_TYPE] #deleting to comply with Rack standard
      env[CONTENT_LENGTH] = env.delete(HTTP_CONTENT_LENGTH) if env[HTTP_CONTENT_LENGTH] #deleting to comply with Rack standard
      env[PATH_INFO] = env[REQUEST_PATH]
      #p "env method call"
      #Webroar.log_info(env.inspect)
      @env = env
    end
    
    #    An HTTP/1.1 server MAY assume that a HTTP/1.1 client intends to
    #    maintain a persistent connection unless a Connection header including
    #    the connection-token "close" was sent in the request.
    #    http://www.w3.org/Protocols/rfc2616/rfc2616-sec8.html
    def keep_alive?
      #Webroar.log_info($g_options["keep_alive"])
      if($g_options["keep_alive"])
        if @env[HTTP_VERSION] == HTTP_1_0 
          return true if @env[HTTP_CONNECTION] =~ KEEP_ALIVE_REGEXP
        else
          return true unless @env[HTTP_CONNECTION] =~ CLOSE_REGEXP
        end
      end
      false
    end
    
    def write_body(body)
      if body.respond_to?(:to_path) and File.exists?(body.to_path)    
        #TODO: Implement 'sendfile' call for kernel-to-kernel transfer.
        file = File.open(body.to_path, 'rb')
        while content = file.read(Webroar::READ_CHUNK_SIZE)
          Webroar::client_write_body(self, content)
        end
        file.close
      elsif body.kind_of?(String)
        Webroar::client_write_body(self, body)
      else        
        body.each {|p|
          Webroar::client_write_body(self, p)
        }
      end      
      Webroar::client_resp_completed(self)      
    end
    
    def write_headers(headers, status, content_length)      
      resp_header = "HTTP/1.1 " + status.to_s + " " + (HTTP_STATUS_CODES[status] || EMPTY_STRING) + "\r\n"      
      headers.each { |field, values|
        if values.is_a?(String)
          values.each_line { |v|
            resp_header += field + ": " + v.chomp + "\r\n"
          }
        else
          values.each { |v|
            resp_header += field + ": " + v.chomp + "\r\n"   
          }
        end
      }
      
      resp_header += "\r\n"
      
      Webroar::client_write_headers(self, status, resp_header, content_length)
      if(content_length <= 0)
        Webroar::client_resp_completed(self)
      end
    end
    
    def body_written
      Webroar::client_set_body_written(self, true)
    end
    
    def begin_transmission
      Webroar::client_begin_transmission(self)
    end
    
    def release
      Webroar::client_release(self)
    end
  end # Client
  Client::BASE_ENV['rack.multithread'] = false #$g_options["threaded_processing"] ? true : false
end # Webroar
