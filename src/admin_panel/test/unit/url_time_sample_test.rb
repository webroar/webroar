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

class UrlTimeSampleTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def setup
    @application_id=5
  end		
  def test_get_url_calls_data
    print "\n Test to get the application URL calls"
    urls,final_data,max,slab=UrlTimeSample.get_url_calls_data(@application_id,Time.now,Time.now.advance(:hours=>1),"requests")
    assert_equal urls.size,final_data.size
    assert_not_nil max	
    assert_not_nil slab
  end
end
