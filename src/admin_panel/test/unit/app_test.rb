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

class AppTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def setup
    @application_name="Insoshi" # give the name of first configured application.
  end		
  def test_get_application_data
    print "\n Test to create and save the application table"
    application= App.new(:name=>"Insoshi",:created_at=>Time.now,:updated_at=>Time.now)
    assert application.save
    application=App.get_application_data(@application_name)
    assert_equal application.id,1
  end
end
