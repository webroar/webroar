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

require 'spec_helper'

# For blog post refer http://stanislavvitvitskiy.blogspot.com/2008/12/multipart-post-in-ruby.html

class Multipart
  
  def initialize( file_names )
    @file_names = file_names
  end
  
  def post(to_url)
    boundary = '----RubyMultipartClient' + rand(1000000).to_s + 'ZZZZZ'
    
    parts = []
    streams = []
    @file_names.each do |param_name, filepath|
      pos = filepath.rindex('/')
      filename = filepath[pos + 1, filepath.length - pos]
      parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"" + param_name.to_s + "\"; filename=\"" + filename + "\"\r\n" +
      "Content-Type: video/x-msvideo\r\n\r\n")
      stream = File.open(filepath, "rb")
      streams << stream
      parts << StreamPart.new(stream, File.size(filepath))
    end
    parts << StringPart.new("\r\n--" + boundary + "--\r\n")
    
    post_stream = MultipartStream.new( parts )
    
    url = URI.parse( to_url )
    req = Net::HTTP::Post.new(url.path)
    req.content_length = post_stream.size
    req.content_type = 'multipart/form-data; boundary=' + boundary
    req.body_stream = post_stream
    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    
    streams.each do |stream|
      stream.close();
    end
    
    res
  end
  
end

class StreamPart
  def initialize( stream, size )
    @stream, @size = stream, size
  end
  
  def size
    @size
  end
  
  def read(offset, how_much)
    @stream.read(how_much)
  end
end

class StringPart
  def initialize ( str )
    @str = str
  end
  
  def size
    @str.length
  end
  
  def read ( offset, how_much )
    @str[offset, how_much]
  end
end

class MultipartStream
  def initialize( parts )
    @parts = parts
    @part_no = 0;
    @part_offset = 0;
  end
  
  def size
    total = 0
    @parts.each do |part|
      total += part.size
    end
    total
  end
  
  def read ( how_much )
    
    if @part_no >= @parts.size
      return nil;
    end
    
    how_much_current_part = @parts[@part_no].size - @part_offset
    
    how_much_current_part = if how_much_current_part > how_much
      how_much
    else
      how_much_current_part
    end
    
    how_much_next_part = how_much - how_much_current_part
    
    current_part = @parts[@part_no].read(@part_offset, how_much_current_part )
    
    if how_much_next_part > 0
      @part_no += 1
      @part_offset = 0
      next_part = read( how_much_next_part  )
      current_part + if next_part
        next_part
      else
        ''
      end
    else
      @part_offset += how_much_current_part
      current_part
    end
  end
end

def create_test_file(min_size=4096,max_size=10240)
  data = rand_data(min_size,max_size)
  File.open(File.join(SPEC_DIR,'test_file'),'wb') do |f|
    f.puts data
  end
end

def upload_file
  file_path = File.join(SPEC_DIR, 'test_file')
  param_name = "file_uploading[file1]"
  
  m = Multipart.new(param_name => file_path)
  m.post("http://#{HOST}:#{PORT}/test_app/test/upload_file")
end

def remove_file
  begin
    File.delete(File.join(SPEC_DIR,'test_file'))
    File.delete(File.join(TEST_APP_PATH,'public','test_file'))
  rescue Errno::ENOENT
    puts "\nThe user might not have write permission on 'public' folder.\n"
  end
end
