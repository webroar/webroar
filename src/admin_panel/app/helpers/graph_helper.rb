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

# Methods added to this helper will be available to all view files for the graph controller.
module GraphHelper
  #This method is used to get the name of the partial to be rendered on selecting the Graph from the select box in the Analytics page.
  def get_partial(url_type)
    case url_type
    when "URL-Calls"
      partial = 'url_calls_graph'
    when "Database-Usage"
      partial = 'database_usage_graph'
    when "URL-Breakup"
      partial = 'url_breakup_graph'
    when "Throughput"
      partial = 'throughput_graph'
    when "Resource-Usage"
      partial='resource_usage_graph_app'
    end
    return partial
  end
end
