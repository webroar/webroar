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

class AddConstraints < ActiveRecord::Migration
  def self.up
    add_index :resource_usages, :app_id
		add_index :resource_usages, :wall_time
		add_index :app_time_samples, :app_id
    add_index :app_time_samples, :wall_time
		add_index :url_time_samples, :app_id
		add_index :url_time_samples, :wall_time
		add_index :url_time_samples, :url
		add_index :url_breakup_time_samples, :app_id
		add_index :url_breakup_time_samples, :wall_time
		add_index :url_breakup_time_samples, :url_sample_id
		add_index :url_breakup_time_samples, :method_name
	end

  def self.down	
    remove_index :resource_usages, :app_id
		remove_index :resource_usages, :wall_time
		remove_index :app_time_samples, :app_id
    remove_index :app_time_samples, :wall_time
		remove_index :url_time_samples, :app_id
		remove_index :url_time_samples, :wall_time
		remove_index :url_time_samples, :url
		remove_index :url_breakup_time_samples, :app_id
		remove_index :url_breakup_time_samples, :wall_time
		remove_index :url_breakup_time_samples, :url_sample_id
		remove_index :url_breakup_time_samples, :method_name
	end	
end
