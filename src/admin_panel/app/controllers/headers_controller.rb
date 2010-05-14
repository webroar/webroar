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

class HeadersController < ApplicationController
  before_filter :login_required
  before_filter :check_session_timeout
  
  def add_expires_text_box        
    render :partial => 'add_expires_text_box'
  end
       
  def cancel_expires_value_edit
    text = params[:old_value].to_s    
    render :text =>   text
  end
  
  def save_expires_value
    text = params[:old_value].to_s    
    if params[:data][:value]
      text, error_message = Headers.validate_and_write_expires_value(text, params[:data][:value])
      if error_message.length > 0
        render :text =>   text.to_s + " <span id='error_div'>#{error_message}</span>"
      else
        render :text =>   text.to_s + " <span id='error_div'>#{RESTART_SERVER_MESSAGE}</span>"
      end
    end
  end
  
  def add_expires_by_type_form
    render :partial => 'expires_by_type_form'
  end
  
  def save_expires_by_type_value    
    @error_message = Headers.validate_and_write_expires_by_type(params[:data][:ext], params[:data][:expires])
    if @error_message.length > 0
      update_div = 'expires_by_type_form'
      partial_name = 'expires_by_type_form'
    else
      update_div = 'headers_div'
      partial_name = 'headers_table'
      @restart_server_message = RESTART_SERVER_MESSAGE
    end   
    render :update do |page|
      page.replace_html update_div, :partial => partial_name  
    end  
  end
  
  def delete_expires_by_type
    Headers.delete_expires_by_type(params[:id].to_i) if params[:id]
    render :partial => 'headers_table'
  end
  
  def cancel_expires_by_type_value
    render :text => ''
  end
end
