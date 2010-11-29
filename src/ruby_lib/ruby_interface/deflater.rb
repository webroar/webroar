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
  
  class Deflater < Rack::Deflater
  
    def initialize(app)
      @app = app
      super
    end
    
    def call(env)
      # Skip compressing entity body if user agent is IE6
      # refer http://schroepl.net/projekte/mod_gzip/browser.htm and 
      # http://support.microsoft.com/default.aspx?scid=kb;en-us;Q313712
      # for problem details
      # 
      if env['HTTP_USER_AGENT'] =~ /MSIE 6.0/
        @app.call(env)
      else       
        super        
      end  
    end
    
  end
  
end