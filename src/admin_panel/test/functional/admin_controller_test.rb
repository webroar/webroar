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
require 'admin_controller'

class AdminControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def setup
    @controller = AdminController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @user_name='admin'
    @user_password='impetus'
    @new_password='ashish'
  end
  
  
  def test_admin #When user goes to index page of admin controller.
    print "\n Test for index page rendering"	
    get :index
    assert_response :success
    assert_select "div[id=login_header]","Admin Panel"
  end
  
  def test_successful_login #When login process is called from admin controller.
    print "\n Test for Successful login"
    get :index
    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    get :configuration
    assert_response :success
    assert_equal "admin",session[:user]
    assert_select "table tr:nth-child(1)","Server Specifications"
  end
  
  def test_unsuccessful_login #When login process is called from  admin controller.
    print "\n Test for unsuccessful login"	
    get :index
    post :login,:user=>{:name=>@user_name,:password=>"asd"}
    get :index
    assert_response :success
    assert_nil session[:user]	
    assert_select "div[id=login_header]","Admin Panel"
  end
  
  def test_unsuccessful_call_to_home #When the user doesnot login before going to home page
    print "\n Test checking before filter in home page login"	
    get :home
    assert_response :redirect
  end
  
  def test_successful_call_to_home #When the user login before going to home page
    print "\n Test for home page after user logged in"	
    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    get :home
    assert_response :success
    assert_select "table tr:nth-child(1)","Server Snapshot"
  end
  
  def test_configuration #testing logout method
    print "\n Test configuration"	
    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    assert_equal "admin",session[:user]
    post :configuration
    assert_select "table tr:nth-child(1)","Server Specifications"
  end
  
  def test_logout #testing logout method
    print "\n Test logout"	
    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    assert_equal "admin",session[:user]
    post :logout
    assert_nil session[:user]
  end
  
  def test_change_password_form
    print "\n Test is to check the functioning of change_password_form function"	
    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    #		get :home
    #	assert_response :success
    #	assert_equal 'admin',session[:user]
    post :change_password_form
    assert_select  "table tr:nth-child(1)","Change Password"
  end	
  
  def test_change_password
    print "\n Test is to check the functioning of change_password function"	

    post :login,:user=>{:name=>@user_name,:password=>@user_password}
    #		get :home
    #	assert_response :success
    #assert_equal 'admin',session[:user]
    post :change_password,:password=>{:old=>@user_password,:new=>@new_password,:confirm=>@new_password}
    assert_response :redirect
    assert_nil session[:user]
    assert_equal PASSWORD_CHANGED,flash[:notice]

    post :login,:user=>{:name=>@user_name,:password=>@new_password}
    assert_equal 'admin',session[:user]
    #		get :home
    #	assert_response :success
    post :change_password,:password=>{:old=>@new_password,:new=>@user_password,:confirm=>@user_password}
    assert_response :redirect
    assert_nil session[:user]
    assert_equal PASSWORD_CHANGED,flash[:notice]
  end
  
end
