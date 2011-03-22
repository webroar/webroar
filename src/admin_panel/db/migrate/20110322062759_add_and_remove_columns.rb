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

class AddAndRemoveColumns < ActiveRecord::Migration
  def self.up
    add_column :app_exceptions, :controller, :string
    add_column :app_exceptions, :method, :string
    if ExceptionDetail.exists?
      say_with_time "update(:app_exceptions)" do
        suppress_messages do
          execute("UPDATE app_exceptions SET
            controller = (SELECT exception_details.controller FROM exception_details WHERE app_exception_id = app_exceptions.id),
            method = (SELECT exception_details.method FROM exception_details WHERE app_exception_id = app_exceptions.id)")
        end
      end
    end
    remove_column :exception_details, :controller
    remove_column :exception_details, :method
  end

  def self.down
  end
end