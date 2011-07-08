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

require "fileutils"

module Webroar
  class User
    def self.permitted?
      return true if File.writable?(TESTFILE)
      puts "#{MESSAGE_DEPLOYMENT}"
      return false
    end
  end
  
  class FileHelper
    def self.copy(src, dest)
      return false unless File.exist?(src)
      FileUtils.copy(src, dest)
      return true
    end
    
    def self.move(src, dest)
      return false unless File.exist?(src)
      FileUtils.move(src, dest)
      return true
    end
    
    def self.remove(src)
      return false unless File.exist?(src)
      FileUtils.remove(src)
      return true
    end
  end 
end  # module Webroar
