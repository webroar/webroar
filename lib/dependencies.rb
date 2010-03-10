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

module Webroar
  class Dependency
  
    def initialize(name)
      @name = name
    end
  
    def name
      @name
    end
  
    def find(options)
      case (@name)
      when File.basename(Config::CONFIG['CC']), "make", Config::CONFIG['RUBY_INSTALL_NAME'], "starling"; flag = find_command(@name)
      when "libsqlite3.so"; flag = find_so(@name, options)
      when "sqlite3.h", "gnutls/gnutls.h"; flag = find_header_file(@name, options)
      when "ruby_headers"; flag = find_header_file("ruby.h", options)
      when "openssl.so"; flag = find_openssl(@name)
      when Config::CONFIG['LIBRUBY_SO']; flag = find_shared_lib()
      when "rubygems"; flag = find_gem(@name)
      when "openssl-ruby"; flag = find_gem("openssl")
      when "zlib-ruby"; flag = find_gem("zlib")
      when "Xcode.app"; flag = find_xcode(@name)
	  else flag = "\e[31mUnknown dependency\e[0m."
      end
      return flag
    end

    private

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

    def find_xcode(name)
      check_file(["/Developer/Applications"], name)
    end

    def find_gem(name)
      begin
        require 'rubygems'
        require name
        flag="\e[32mfound\e[0m."
      rescue LoadError
        flag="\e[31mnot found\e[0m.\nUnable to find #{name} gem."
      end
      flag
    end
    
    def find_command(name)
      arr = ENV['PATH'].split(File::PATH_SEPARATOR)
      arr.delete("") if arr!= nil
      return "\e[31mnot found\e[0m.\nUnable to find #{name} from 'PATH'." if arr.nil? or arr.length == 0
      check_file(arr, name)
    end

    def find_so(name, options)
      arr = []
      arr += ENV['LD_LIBRARY_PATH'].split(File::PATH_SEPARATOR) if ENV['LD_LIBRARY_PATH']
      arr += ["/usr/lib"]
      arr += options[:library_paths].gsub(' -L','').gsub("''",":").gsub("'",'').split(File::PATH_SEPARATOR) if options[:library_paths]
      arr.delete("")

      check_file(arr, name)
    end

    def find_header_file(name, options)
      arr = []

      begin
        require 'rbconfig'
        require 'mkmf'
        arr += [Config::CONFIG['archdir'], Config::CONFIG['sitearchdir']]
      end

      arr += ["/usr/include"]
      arr += options[:include_paths].gsub(" -I",'').gsub("''",":").gsub("'",'').split(File::PATH_SEPARATOR) if options[:include_paths]
      arr.delete("")

      check_file(arr, name)
    end

    def find_openssl(name)
      begin
        require 'rbconfig'
        require 'mkmf'

        check_file([Config::CONFIG['archdir'], Config::CONFIG['sitearchdir']], name)

      rescue LoadError
        return "\e[31mnot found\e[0m.\nUnable to find #{name} at #{[Config::CONFIG['archdir'], Config::CONFIG['sitearchdir']] * ','}."
      end
    end

    def check_file(dirs, file)

      dirs.each do |dir|
        return "\e[32mfound\e[0m   at #{File.join(dir, file)}." if File.exist?(File.join(dir, file))
      end
      
      return "\e[31mnot found\e[0m.\nUnable to find #{file} at #{dirs * ','}."
    end

  end
  
  module Dependencies 
    GCC = Dependency.new(File.basename(Config::CONFIG['CC']))
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
