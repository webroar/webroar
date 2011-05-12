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
require 'test_helper'
require 'application_specification_controller'

class ApplicationSpecificationControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def setup
    @controller = ApplicationSpecificationController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @user_name='admin'
    @user_password='impetus'
    @new_password='ashish'
  end
  
  def test_add_application
    print "\n Test is to add application"	
    create_session_for_Application_Specification
    get :add_application_form
    assert_response :success  
    post :add_application, :application_specification => { :name => 'Insoshi', :resolver => '/in', :path => "/home/ashish/work/rails_projects/insoshi", :run_as_user => 'ashish', :type1 => 'rails', :analytics => 'enabled', :environment => 'production', :min_worker => 1, :max_worker => 2 }
  end
  
  def test_add_application_form
    print "\n Test is to add application form"	
    create_session_for_Application_Specification
    get :add_application_form
    assert_select  "table tr:nth-child(1)","Add Application"
  end
  
  def test_edit_application_form
    print "\n Test is to edit application form"	
    create_session_for_Application_Specification
    get :edit_application_form,:id=>0
    assert_select  "table tr:nth-child(1)","Edit Application"
  end
  
  def test_edit_application
    print "\n Test is to edit application"	
    create_session_for_Application_Specification
    post :edit_application, :id => 0, :application_specification => { :name => 'Insoshi', :resolver => '/insoshi', :path => "/home/ashish/work/rails_projects/insoshi", :run_as_user => 'ashish', :type1 => 'rails', :analytics => 'enabled', :environment => 'production', :min_worker => 1, :max_worker => 2 }
  end  
end
