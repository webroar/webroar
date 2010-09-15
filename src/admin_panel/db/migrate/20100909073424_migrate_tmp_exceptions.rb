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

class MigrateTmpExceptions < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.connection.tables.include?("tmp_exceptions")

      say_with_time "migrate_table(tmp_exceptions, :app_exceptions) ..." do
        suppress_messages do
          execute("insert into 
                    app_exceptions(app_id, exception_message, exception_class, 
                    exception_status, exceptions_count) 
                    select app_id, exception_message, exception_class, 
                    exception_status, count(exception_message)
                    from tmp_exceptions group by app_id, exception_message") 
        end
      end
                     
      say_with_time "migrate_table(:tmp_exceptions, :exception_details) ..." do
        suppress_messages do
          execute("insert into 
                    exception_details(app_exception_id,app_env,controller,method,
                    exception_backtrace,chunked,content_length,http_accept,
                    http_accept_charset,http_accept_encoding,http_accept_language,
                    http_connection,http_cookie,http_host,http_keep_alive,
                    http_user_agent,http_version,path_info,query_string,
                    remote_addr,request_method,request_path,request_uri,
                    script_name,server_name,server_port,server_protocol,
                    server_software,rack_errors,rack_input,rack_multiprocess,
                    rack_multithread,rack_run_once,rack_url_scheme,
                    rack_version,wall_time)
                    select a.id, app_env,controller,method,
                    exception_backtrace,chunked,content_length,http_accept,
                    http_accept_charset,http_accept_encoding,http_accept_language,
                    http_connection,http_cookie,http_host,http_keep_alive,
                    http_user_agent,http_version,path_info,query_string,
                    remote_addr,request_method,request_path,request_uri,
                    script_name,server_name,server_port,server_protocol,
                    server_software,rack_errors,rack_input,rack_multiprocess,
                    rack_multithread,rack_run_once,rack_url_scheme,
                    rack_version,wall_time 
                    from app_exceptions as a, tmp_exceptions t
                    where a.app_id = t.app_id 
                    and a.exception_message = t.exception_message")
        end
      end    
    end
  end

  def self.down
  end
end
