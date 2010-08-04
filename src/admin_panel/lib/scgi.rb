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

require 'jcode' if RUBY_VERSION.gsub(/\D/,'').to_i < 187
#This class contructs and parse the SCGI request.
class SCGI
#  @hash #Instance variable to store SCGI headers.
#  @request #Instance variable to store SCGI request in single string value.
#  @body #Instance variable to store SCGI request body.

  #This is the constructor function for SCGI class.
  def initialize
    @hash = Hash.new
    @body = ''
    @tmp_headers_length = ''
    @headers_length = 0
    @curr_state = :SCGI_NONE
    @curr_key = ''
    @curr_value = ''
    @done = false
  end
  
  def parsing_done?
    @done    
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
    @body += body
  end
  
  #Getter method for receiving SCGI headers.
  def header(key)
    @hash[key.upcase]
  end
  
  #Construct SCGI request.
  def build
    if(@body == '')
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
    index = 0
    req.each_char do |c|      
      case @curr_state
        when :SCGI_NONE
          if c == ':'
            @headers_length = @tmp_headers_length.to_i
            @curr_state = :HEADER_KEY
          elsif c < '0' or c > '9' 
            @curr_state = :INVALID
          else
            @tmp_headers_length += c
          end
        when :HEADER_KEY
          if c == "\0"            
            @curr_state = :HEADER_VAL
          elsif c == ","
            if header('CONTENT_LENGTH').to_i == 0
              @done = true
              @curr_state = :DONE
            else
              @curr_state = :BODY
              body_add(req[index+1, req.length])
              if @body.length == header('CONTENT_LENGTH').to_i
                @curr_state = :DONE
                @done = true
              else
                @curr_state = :BODY
              end
              break
            end
          else
            @curr_key += c            
          end
        when :HEADER_VAL
          if c == "\0"            
            header_add(@curr_key, @curr_value)
            @curr_key = ''
            @curr_value = ''
            @curr_state = :HEADER_KEY
          else
            @curr_value += c
          end
        when :BODY
          body_add(req[index, req.length])
          if @body.length == header('CONTENT_LENGTH').to_i
            @curr_state = :DONE
            @done = true
          end
          break
        when :DONE
          @done = true
          return
      end    
      index += 1
    end    
  end  
end
