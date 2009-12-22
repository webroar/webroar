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

require 'mkmf'
if ENV['LD_LIBRARY_PATH'].nil?
  ENV['LD_LIBRARY_PATH'] = ":/usr/lib:/usr/include"
else
  ENV['LD_LIBRARY_PATH'] += ":/usr/lib:/usr/include"
end

module Webroar
  class Dependency
  
    def initialize(name)
      @name=name
    end
  
    def name
      @name
    end
  
    def find
      name = @name
      case (name)
      when Config::CONFIG['CC'], "make", Config::CONFIG['RUBY_INSTALL_NAME'], "starling"; flag = find_command(name)
      when "libsqlite3.so", "sqlite3.h", "gnutls/gnutls.h"; flag = find_so(name)
      when "ruby_headers"; flag = find_ruby_headers()
      when "openssl.so"; flag = find_openssl(name)
      when Config::CONFIG['LIBRUBY_SO']; flag = find_shared_lib()
      when "rubygems"; flag = find_gem(name)
      when "openssl-ruby"; flag = find_gem("openssl")
      when "zlib-ruby"; flag = find_gem("zlib")
      when "Xcode.app"; flag = find_Xcode(name)
      end
      return flag
    end
    
    def find_shared_lib()
      if File.exist?(File.join(Config::CONFIG['libdir'],Config::CONFIG['LIBRUBY_SO']))
        flag = "\e[32mfound\e[0m  at #{Config::CONFIG['libdir']}."
      elsif Config::CONFIG['ENABLE_SHARED'] == 'yes'
        flag = "\e[32mfound\e[0m."
      else
        flag="\e[31mnot found\e[0m.\nUnable to find #{Config::CONFIG['LIBRUBY_SO']} at #{Config::CONFIG['libdir']}."        
      end
      return flag
    end
    
    def find_Xcode(name)      
      directory="/Developer/Applications"
      if File.exist?(directory+"/#{name}")
        flag="\e[32mfound\e[0m   at #{directory}/#{name}."
        return flag        
      end
      flag="\e[31mnot found\e[0m.\nUnable to find #{name} at #{directory}."
      return flag
    end
    
    def find_command(name)
      ENV['PATH'].split(File::PATH_SEPARATOR).detect do |directory|
        path = File.join(directory, File.basename(name))
        if File.executable?(path)
          flag="\e[32mfound\e[0m   at #{path}."
          return flag
        end
      end
      flag = nil
      arr = ENV['PATH'].split(File::PATH_SEPARATOR)
      arr.delete("") if arr!= nil
      if arr == nil or arr.length == 0
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} from 'PATH'."
      elsif arr.length == 1
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} at #{arr}."
      else
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} at any of these locations #{arr*","}"
      end 
      return flag
    end  
  
    def find_so(name)
      ENV['LD_LIBRARY_PATH'].split(File::PATH_SEPARATOR).detect do |directory|
        if File.exist?(directory+"/#{name}")
          flag="\e[32mfound\e[0m   at #{directory}/#{name}."
          return flag
        end
      end
      flag = nil
      arr = ENV['LD_LIBRARY_PATH'].split(File::PATH_SEPARATOR)
      arr.delete("") if arr!= nil
      if arr == nil or arr.length == 0
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} from 'LD_LIBRARY_PATH'."
      elsif arr.length == 1
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} at #{arr}."
      else
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} at any of these locations #{arr*","}"
      end 
      return flag
    end  
    
    def find_ruby_headers
      begin
        require 'rbconfig'
        require 'mkmf'
        ruby_header_dir = Config::CONFIG['rubyhdrdir'] || Config::CONFIG['archdir']
        if File.exist?("#{ruby_header_dir}/ruby.h")
          flag="\e[32mfound\e[0m   at #{ruby_header_dir}/ruby.h."
          return flag
        else
          flag="\e[31mnot found\e[0m.\nUnable to find ruby.h at #{ruby_header_dir}."
          return flag
        end
      rescue LoadError
        flag="\e[31mnot found\e[0m.\nUnable to find ruby.h at #{ruby_header_dir}."
        return flag
      end
    end
  
    def find_openssl(name)
      begin
        require 'rbconfig'
        require 'mkmf'
        if File.exist?(Config::CONFIG['archdir'] +"/"+ name) or 
            File.exist?(Config::CONFIG['sitearchdir'] +"/"+ name)
          flag="\e[32mfound\e[0m   at #{Config::CONFIG['archdir']}/#{name}."
          return flag
        else
          flag="\e[31mnot found\e[0m.\nUnable to find #{name} at #{Config::CONFIG['archdir']}."
          return flag
        end
      rescue LoadError
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} at #{Config::CONFIG['archdir']}."
        return flag
      end
    end
  
    def find_gem(name)
      begin
        require 'rubygems'
        require name
        flag="\e[32mfound\e[0m."
      rescue LoadError
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} gem."
      end
      return flag
    end
    
    
  end    
  module Dependencies 
    GCC = Dependency.new(Config::CONFIG['CC'])
    Gnutls = Dependency.new('gnutls/gnutls.h')
    Make = Dependency.new('make')
    LibRuby = Dependency.new(Config::CONFIG['LIBRUBY_SO'])
    LibSqlite = Dependency.new('libsqlite3.so')
    Ruby_OpenSSL = Dependency.new('openssl-ruby')
    Ruby = Dependency.new(Config::CONFIG['RUBY_INSTALL_NAME'])
    Ruby_DevHeaders = Dependency.new('ruby_headers')
    RubyGems = Dependency.new('rubygems')
    Sqlite_DevHeaders = Dependency.new('sqlite3.h')
    Starling = Dependency.new('starling')
    Xcode = Dependency.new('Xcode.app')
    Zlib = Dependency.new('zlib-ruby')
  end
end # module Webroar
