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

# RequestBody class based on ebb server's http://github.com/ry/ebb/tree/v0.1.0
require 'stringio'
module Webroar
  class RequestBody
    def initialize(client)
      @client = client
    end
    
    def read(len = nil)
      if @io
        @io.read(len)
      else
        if len.nil?
          s = ''
          while(chunk = read(10*1024))
            s << chunk
          end
          s
        else
          Webroar::read_request(@client, len)
        end
      end
    end
    
    def gets
      io.gets
    end
    
    def each(&block)
      io.each(&block)
    end
    
    def io
      @io ||= StringIO.new(read)
    end
    
    # Adding rewind method to meet Rack specification.
    def rewind
      @io.rewind if @io
    end
  end # RequestBody
end # Webroar
