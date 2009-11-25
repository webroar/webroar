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

class MailSpecificationController < ApplicationController
  before_filter :login_required #This method checks whether user is authenticated or not.
  before_filter :check_session_timeout
  
  #Method is used to render the sendmail settings form.
  def sendmail_form
    @sendmail_old = MailSpecification.sendmail_specification_hash
    render :partial => "sendmail_form"
  end 
    
  #Method is used to render the smtp settings form.
  def smtp_form
    @smtp_old = MailSpecification.smtp_specification_hash
    render :partial => "smtp_form"
  end 
  
  #Method is used to edit the smtp settings and renders the smtp form.
  def edit_smtp
    @smtp_old = params[:smtp]
    render :partial => "smtp_form"
  end
  
  #Method is used to edit the sendmail settings and renders the sendmail form.
  def edit_sendmail
    @sendmail_old = params[:sendmail]
    render :partial => "sendmail_form"
  end
  
  #Method is used to save the sendmail settings.
  def save_sendmail_settings   
    str = MailSpecification.validate_sendmail_specification(params[:sendmail])
    if str.length < 1
      MailSpecification.save_sendmail_specification(params[:sendmail])      
    else
      sendmail = MailSpecification.sendmail_specification_hash(params[:sendmail])
      flash[:sendmail_errors] = str
    end
    redirect_to :controller => 'admin', :action => 'configuration', :sendmail => sendmail
  end
  
  #Method is used to save the smtp settings.
  def save_smtp_settings  
    str = MailSpecification.validate_smtp_specification(params[:smtp])
    if str.length < 1
      MailSpecification.save_smtp_specification(params[:smtp])
    else
      smtp = MailSpecification.smtp_specification_hash(params[:smtp])
      flash[:smtp_errors] = str        
    end
    redirect_to :controller => 'admin', :action => 'configuration', :smtp => smtp
  end
  
end
