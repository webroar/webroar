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

require File.dirname(__FILE__) + '/../test_helper'

class GraphControllerTest < ActionController::TestCase
  def setup
    @controller = GraphController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @user_name='admin'
    @user_password='impetus'
  end
  
  def test_unsuccessful_login_to_index_page_of_graph_controller
    print "\n Test to check unsuccessful login to index page of graph controller"
    get :index
    assert_response :redirect
  end
  
  def test_successful_login_to_index_page_of_graph_controller
    print "\n Test to check successful login to index page of graph controller"
    create_session
    get :index
    assert_response :success
  end
end
