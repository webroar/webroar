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

class AppTimeSampleTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def setup
    @application_id=5
  end		
  def test_get_application_data
    print "\n Test to fetch the row from 'db' table."
    wall_time,final_data,max,slab = AppTimeSample.get_application_data(@application_id,Time.now,Time.now.advance(:hours=>1),"db")
    assert_not_nil wall_time
    assert_not_nil final_data
    assert_not_nil max
    assert_not_nil slab
    print "\n Test to fetch the row from 'throughput' table"
    wall_time,final_data,max,slab = AppTimeSample.get_application_data(@application_id,Time.now,Time.now.advance(:hours=>1),"throughput")
    assert_not_nil wall_time
    assert_not_nil final_data
  end
end
