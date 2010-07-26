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
require 'date'

#Class to send SCGI control message on socket. It also receive and parse the acknowledge message.
class Control
  @@LOG_DIR = File.join('','var','log','webroar')
  
  # Constructor.
  def initialize(name)
    @name = name	# Application name
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

  private

  # Build and send SCGI control message.
  def send_control
    @req.build
    sockFile = File.join("","tmp","webroar.sock")
    
    if !File.exist?(sockFile)
      return "Either the server is not started or 'webroar.sock' file is deleted.", nil
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
    start_time = DateTime.parse(Time.now.strftime("%a %b %d %H:%M:%S %Y"))
    str = streamSock.recv(2048)
    @resp = SCGI.new
    @resp.parse(str)
    until @resp.parsing_done?
      str = streamSock.recv(2048)
      @resp.parse(str)
    end
    end_time = DateTime.parse(Time.now.strftime("%a %b %d %H:%M:%S %Y"))
    streamSock.close
    if @resp.header("STATUS") == "OK" or @resp.header("STATUS") == "ok"
      return nil, nil
    else
      if @resp.body == nil
        return "Error: Operation not performed.", get_error_log(start_time, end_time)
      else
        return @resp.body, get_error_log(start_time, end_time)
      end
    end
  end

  def get_error_log(start_time, end_time)
    # Open a log file
    file_name = File.join(@@LOG_DIR, @name+'.log')
    return nil if !File.file?(file_name)
    log_file = File.open(file_name,"r")
    err_log = ""
    flag = false
    error = false
    log_file.each_line do |x|
      # Set write flag if logged after strat date.
      if !flag and check_date(x)
        flag = true if DateTime.parse(x) >= start_time
      end

      # Stop if logged after end date.
      if flag and check_date(x)
        break if DateTime.parse(x) > end_time
      end
      error = true if !error and flag and x.include? "-Error:"
      err_log += x if error

    end

    err_log.length > 1 ? err_log : nil

  end

  def check_date(str)
    /^(Sun|Mon|Tue|Wed|Thu|Fri|Sat) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) {1,2}\d{1,2} {1,2}\d{1,2}:\d{1,2}:\d{1,2} \d{4}/.match(str)
  end
  
end #Class end
