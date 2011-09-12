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

class TestController < ApplicationController

  def not_modified
    render :text => 'ok', :status => 304
  end
  
  def host_name
    render :text => 'ok'
  end
  
  def access_log
    render :text => 'ok'
  end
  
  def chunked_header
    render :text => 'ok'
  end

  def keep_alive
    render :text => 'ok'
  end
  
  def stuck_worker
#    sleep(400)
    sleep(200)
    render :text => 'ok'
  end
  
  def half_stuck_worker
#    sleep(100)
    sleep(75)
    render :text => 'ok'
  end
  
  def content_encoding
    render :text => 'ok'
  end
  
  def query_string
    if params[:foo] == 'bar' and params[:zig] = 'zag'
      render :text => 'ok'
    else
      render :status => 404, :text=>'Not Found'
    end
  end
  
  def post_data
    if request.post?
      if params[:post_data][:name] == 'a'
        render :text => 'ok'
      else
        render :status => 404, :text => 'Not Found'
      end
      return
    end
    render :action => :post_data
  end
  
  def upload_file
    if request.post?
      if params[:file_uploading][:file1]!=""
        name=params[:file_uploading][:file1].original_filename
        path=File.join(RAILS_ROOT,'public',name)
        File.open(path,'wb') do |file|
          file.puts params[:file_uploading][:file1].read
        end
        flash[:notice] = 'File uploaded.'
      end
    end
    render :action => :upload_file
  end

end
