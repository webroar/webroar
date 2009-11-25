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
#
class User < PseudoModel  
  column :name, :string
  column :password, :string
  
  class << self
    # Returns true if everything is fine, else error message
    def authenticate(username, password)     
      rv = ''
      if !username or username == ""               
        return rv += USERNAME_BLANK        
      end
      if password == ""
        return rv += PASSWORD_BLANK        
      end
      return rv unless rv == ''      
      users = YAML::load_file(USERS_FILE_PATH)      
      users.each do |user|
        if(username == user['user_name'] && Digest::MD5.hexdigest(password) == user['password'])
          return true        
        end
      end
      return rv += WRONG_LOGIN_DETAILS
    end
    
    
  end
    
end