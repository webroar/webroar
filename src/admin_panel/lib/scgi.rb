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

#This class contructs and parse the SCGI request.
class SCGI
  @hash #Instance variable to store SCGI headers.
  @request #Instance variable to store SCGI request in single string value.
  @body #Instance variable to store SCGI request body.
  
  #This is the constructor function for SCGI class.
  def initialize
    @hash = Hash.new
  end
  
  #Getter setter for request in SCGI class.
  def request
    @request
  end
  
  #Getter setter for body in SCGI class.
  def body
    @body
  end
  
  #This method is used to add the headers.
  def header_add(key, value)
    @hash[key.upcase] = value
  end
  
  #Adds SCGI request body.
  def body_add(body)
    @body = body
  end
  
  #Getter method for receiving SCGI headers.
  def header(key)
    @hash[key.upcase]
  end
  
  #Construct SCGI request.
  def build
    if(@body == nil)
      @request = "CONTENT_LENGTH\0"+"0"+"\0"
    else
      @request = "CONTENT_LENGTH\0#{body.length}\0"
    end
    @request += "SCGI\0"+"0" +"\0"
    @hash.each_key{|key|
      @request += "#{key}\0#{@hash[key]}\0"
    }
    @request = "#{@request.length}:#{@request}"
    @request += ",#{@body}"
  end
  
  #Display SCGI request.
  def print
    @hash.each_key{|key|
      puts "#{key}:#{@hash[key]}"
    }
    puts ","
    puts @body
  end
  
  #Parse the string and build SCGI request.
  def parse(req)
    arr = req.split(":")
    key = ""
    len = arr[0]	#TODO if len.to_i == 0 then error
    arr = arr[1].split("\0", len.to_i)
    arr.each_index {|i|
      if(i % 2 == 0)
        key = arr[i]
      else
        header_add(key, arr[i])
      end
    }
    arr = arr[-1].split(",")
    body_add(arr[-1])
  end
end
