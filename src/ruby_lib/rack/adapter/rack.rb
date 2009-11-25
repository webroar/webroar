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

require 'rubygems'
require 'rack'

module Webroar  
  module Adapter     
    class Rack
      def initialize(options={})
        @root = options['root'].freeze           
        @prefix_regexp = Regexp.new((options['prefix'] || '/')).freeze
        ENV['APP_ROOT'] = options['root']
        ENV['APP_ENV'] = options["environment"]
        ENV['APP_BASE_URI'] = options["prefix"] || '/'
        @file_server = ::Rack::File.new(::File.join(@root, "public"))
        Dir.chdir(@root) # Some application uses current directory to map other files.
  	    $0 = 'webroar' # Some application using it to retrive executable name.
        cfgfile = ::File.read('config.ru')
        @app = eval("::Rack::Builder.new {( " + cfgfile + "\n )}.to_app", nil, 'config.ru')
      end
      
      def file_exist?(path)
        full_path = ::File.join(@file_server.root, ::Rack::Utils.unescape(path))	
        ::File.file?(full_path) && ::File.readable?(full_path)
      end
    
      def serve_file(env)
        @file_server.call(env)
      end
    
      def call(env)
        match = @prefix_regexp.match(env[Webroar::REQUEST_PATH])         
    	  env[Webroar::SCRIPT_NAME] = match.to_s         
        env[Webroar::PATH_INFO] = env[Webroar::REQUEST_PATH] = match.post_match
  	    path = env[Webroar::PATH_INFO].chomp(Webroar::SLASH)				
    	  if file_exist?(path)              # Serve the file if it's there
          serve_file(env)
    	  else				# TODO: Serve cached page
    	    @app.call(env)
    	  end
      end
    end  
  end

end
      
