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

#This is the model class UrlBreakupTimeSample related to the url_breakup_samples table in the database.
class UrlBreakupTimeSample < ActiveRecord::Base
  belongs_to :app
  class << self
    #This method gives the data details for the url in the table. The url data is retrived with the help of url ids.
    #The array of url id is supplied as input to this method.
    def get_url_breakup_sample_data(url_id)
      criteria = "url_sample_id in (" + (url_id.join(", ") || '') + ')'
      return select('method_name,
                    sum(spent_time) as time_spent'
                    ).where(criteria
                    ).group(:method_name
                    ).order('time_spent desc')
    end
  end
end
