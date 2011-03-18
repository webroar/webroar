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

module Webroar
  module ExceptionTracker
    def trace_rescue_action(method_name, parent_name, method_type)
      code=get_logging_code 
      if method_name.to_s =~ /([=\]><~])$/
        Webroar.log_info("Can not rescue #{method_name.to_s}")
        return
      end
      without_rescue_name = "without_webroar_exception_#{method_name}"
      with_rescue_name = "with_webroar_exception_#{method_name}"
      if defined? parent_name
        patch = <<-EOL
                def #{with_rescue_name}(*args, &block)
                    #{code}  
                    result = #{without_rescue_name}(*args, &block)
                    result
                  end
                  alias #{without_rescue_name} #{method_name}
                  alias #{method_name} #{with_rescue_name}
                EOL
        parent_name.class_eval(patch, __FILE__, __LINE__)
      else
        raise NameError, "#{parent_name.inspect} is not a valid constant name!"
      end
    end #trace_method
    
    def  get_logging_code
      code = <<-CODE
                  Thread.current[:exception_hash]={:controller=>self.class.controller_path,:method=>action_name.to_s,:exception_message=>args[0].message.to_s,:exception_class=>args[0].class.to_s,:exception_backtrace=>args[0].backtrace.join("\n"),:wall_time=>Time.now,:chunked=>request.env['CHUNKED'],:content_length=>request.env['CONTENT_LENGTH'],:http_accept=>request.env['HTTP_ACCEPT'],:http_accept_charset=>request.env['HTTP_ACCEPT_CHARSET'],:http_accept_encoding=>request.env['HTTP_ACCEPT_ENCODING'],:http_accept_language=>request.env['HTTP_ACCEPT_LANGUAGE'],:http_connection=>request.env['HTTP_CONNECTION'],:http_cookie=>request.env['HTTP_COOKIE'],:http_host=>request.env['HTTP_HOST'],:http_keep_alive=>request.env['HTTP_KEEP_ALIVE'],:http_user_agent=>request.env['HTTP_USER_AGENT'],:http_version=>request.env['HTTP_VERSION'],:path_info=>request.env['PATH_INFO'],:query_string=>request.env['QUERY_STRING'],:remote_addr=>request.env['REMOTE_ADDR'],:request_method=>request.env['REQUEST_METHOD'],:request_path=>request.env['REQUEST_PATH'],:request_uri=>request.env['REQUEST_URI'],:script_name=>request.env['SCRIPT_NAME'],:server_name=>request.env['SERVER_NAME'],:server_port=>request.env['SERVER_PORT'],:server_protocol=>request.env['SERVER_PROTOCOL'],:server_software=>request.env['SERVER_SOFTWARE'],:rack_errors=>request.env["rack.errors"].to_s,:rack_input=>request.env["rack.input"].to_s,:rack_multiprocess=>request.env["rack.multiprocess"].to_s,:rack_multithread=>request.env["rack.multithread"].to_s,:rack_run_once=>request.env["rack.run_once"].to_s,:rack_url_scheme=>request.env["rack.url_scheme"].to_s,:rack_version=>request.env["rack.version"].to_s}
                  Webroar::Profiler::MessageDispatcher.instance.log_exception(Thread.current[:exception_hash])
                CODE
      code
    end
    module_function(:trace_rescue_action,:get_logging_code)
  end # ExceptionTracker
end # Webroar

require File.join(File.dirname(__FILE__), 'instrumentation', 'instrumentation.rb')
