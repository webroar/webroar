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

class CreateAppTimeSamples < ActiveRecord::Migration
  def self.up
    create_table :app_time_samples do |t|
      t.integer :app_id
      t.float :total_time_in_request
      t.float :db_time
      t.float :rendering_time
      t.integer :number_of_requests
      t.integer :sampling_rate # in seconds
      t.float :avg_response_time # in miliseconds
      t.integer :peak_requests_served
      t.timestamp :wall_time
    end
  end

  def self.down
    drop_table :app_time_samples
  end
end
