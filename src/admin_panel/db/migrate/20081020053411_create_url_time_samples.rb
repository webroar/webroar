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

class CreateUrlTimeSamples < ActiveRecord::Migration
  def self.up
    create_table :url_time_samples do |t|
      t.integer :app_id
      t.string :url, :limit=>512
      t.float :total_time
			t.float :db_time
			t.float :rendering_time
			#make pseudo column for remaining time in rails model
			t.integer :number_of_requests
			t.integer :sampling_rate # in seconds
      t.timestamp :wall_time
    end
  end

  def self.down
    drop_table :url_time_samples
  end
end
