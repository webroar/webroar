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

require 'socket'
require 'scgi'

#Class to send SCGI control message on socket. It also receive and parse the acknowledge message.
class Control
  
  # Constructor.
  def initialize(name)
    @name=name	# Application name
    @req = SCGI.new	# SCGI control message
    @req.header_add("component","APPLICATION")
    @req.header_add("app_name",@name)
  end
  
  # Getter, setter method for Application name
  def name
    return @name
  end
  
  # Send control message to deploy newly added Applicaiton.
  def add
    @req.header_add("method","ADD")
    send_control
  end
  
  # Send control message to stop Applicaiton.
  def delete
    @req.header_add("method","REMOVE")
    send_control
  end
  
  # Send control message to refresh Applicaiton.
  def restart
    @req.header_add("method","RELOAD")
    send_control
  end
  
  # Build and send SCGI control message.
  def send_control
    @req.build
    sockFile = File.join("","tmp","webroar.sock")
    
    if !File.exist?(sockFile)
      return "Either altas-server is not started or 'webroar.sock' file is deleted."  
    end
    
    file = File.new(sockFile)
    port = file.gets
    file.close
    if(port.to_i == 0)
      streamSock = UNIXSocket.new(port)
    else
      streamSock = TCPSocket.new( "127.0.0.1", port.to_i)
    end
    streamSock.send(@req.request, 0)
    str = streamSock.recv(2048)
    streamSock.close
    @resp = SCGI.new
    @resp.parse(str)
    
    if @resp.header("STATUS") == "OK" or @resp.header("STATUS") == "ok"
      return nil
    else
      if @resp.body == nil
        return "Error: Operation not performed."
      else
        return @resp.body
      end
    end
  end
  
end #Class end
