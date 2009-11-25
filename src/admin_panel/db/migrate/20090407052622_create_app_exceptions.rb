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

class CreateAppExceptions < ActiveRecord::Migration
  def self.up
    create_table :app_exceptions do |t|
      t.integer :app_id
      t.string :app_env
      t.string :controller
      t.string :method
      t.string :exception_message, :limit=>100
      t.string :exception_class, :limit=>100
      t.text :exception_backtrace
      t.integer :exception_status,:size=>1      
      t.string :chunked
      t.string :content_length
      t.string :http_accept
      t.string :http_accept_charset
      t.string :http_accept_encoding
      t.string :http_accept_language
      t.string :http_connection
      t.text :http_cookie
      t.string :http_host
      t.string :http_keep_alive
      t.string :http_user_agent
      t.string :http_version
      t.string :path_info
      t.string :query_string
      t.string :remote_addr
      t.string :request_method
      t.string :request_path
      t.string :request_uri
      t.string :script_name
      t.string :server_name
      t.string :server_port
      t.string :server_protocol
      t.string :server_software
      t.string :rack_errors
      t.string :rack_input
      t.string :rack_multiprocess
      t.string :rack_multithread
      t.string :rack_run_once
      t.string :rack_url_scheme
      t.string :rack_version
      t.timestamp :wall_time
    end
  end
  def self.down
    drop_table :app_exceptions
  end
end
