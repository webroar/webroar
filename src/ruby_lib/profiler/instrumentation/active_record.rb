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

module Webroar
  module Profiler
    trace_database_method(:find, ActiveRecord::Base, 'c')
    trace_database_method(:delete_all, ActiveRecord::Base, 'c')
    trace_database_method(:save, ActiveRecord::Base, 'i')
    trace_database_method(:destroy, ActiveRecord::Base, 'i')
    
    # Comment out following lines, if you not interested in detailed analysis of ActiveRecord Models
#    exclude_list = [Object, ActiveRecord::Base]
#    if defined? ActiveRecord::SessionStore::Session
#      exclude_list << ActiveRecord::SessionStore::Session
#    end
#    ObjectSpace.each_object(Class) { |c|
#      if c.ancestors.include?(ActiveRecord::Base)
#        unless exclude_list.include?(c)
#          puts "class = #{c.ancestors[0]}"        
#          c.methods(false).each { |m|
#            puts m
#            trace_database_method(m.to_sym, c.ancestors[0], 'c')
#          }
#          c.instance_methods(false).each { |m|
#            puts m
#            trace_database_method(m.to_sym, c.ancestors[0], 'i')
#          }
#        end
#      end
#    }
    
  end # Profiler
end # Webroar
