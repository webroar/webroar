require 'cgi'
require 'rubygems'
require 'rack'
#require 'ruby-debug' #for debugging
#Debugger.start #for debugging

# Adapter to run a Rails app with any supported Rack handler.
# By default it will try to load the Rails application in the
# current directory in the development environment.
# Options:
#  root: Root directory of the Rails app
#  env: Rails environment to run in (development, production or test)
# Based on http://fuzed.rubyforge.org/ Rails adapter
module Webroar 
  module Adapter 
    class Rails
      
      def initialize(options={})		
        # TODO: Keys are strings setup in C, check how to setup as symbols        
        @root   = (options["root"]         || Dir.pwd).freeze         
        @env    = (options["environment"]  || 'development').freeze         
        @prefix = (options["prefix"] || '/').freeze         
        @prefix_regexp = Regexp.new(@prefix).freeze
        Dir.chdir(options["root"]) # Some application uses current directory to map other files.
        $0 = 'webroar' # Some application using it to retrive executable name.
        load_application
        
        @rails_app = if defined?(ActionController::Dispatcher) and ActionController::Dispatcher.instance_methods.include?('call')
          ActionController::Dispatcher.new
        elsif ::Rails::VERSION::MAJOR >= 3
          ::Rails.application
        else
          CgiApp.new
        end
        
        @file_server = ::Rack::File.new(::File.join(@root, "public"))
      end
      
      def load_application
        ENV['RAILS_ENV'] = @env
        
        require "#{@root}/config/environment"
#        TODO: figure out way to set relative URL, following is not working on Rails3-beta4 for stylesheet_link_tag, javascript_include_tag
        if ::Rails::VERSION::MAJOR >= 3
          ::Rails.application.config.relative_url_root = @prefix
        else
          require 'dispatcher'
          if ActionController::Base.respond_to?('relative_url_root=') 
            ActionController::Base.relative_url_root = @prefix # new way to set the relative URL in Rails 2.1.1 
          else 
            ActionController::AbstractRequest.relative_url_root = @prefix
          end
        end
      end
      
      # TODO refactor this in File#can_serve?(path) ??
      def file_exist?(path)
        full_path = ::File.join(@file_server.root, ::Rack::Utils.unescape(path))	
        ::File.file?(full_path) && ::File.readable?(full_path)
      end
      
      def serve_file(env)
        @file_server.call(env)
      end
      
      def call(env)
        #following three lines are copied from mongrel to resolve prefix issue.         
        match = @prefix_regexp.match(env[Webroar::REQUEST_PATH])         
        env[Webroar::SCRIPT_NAME] = match.to_s         
        env[Webroar::PATH_INFO] = match.post_match    
        path        = env[Webroar::PATH_INFO].chomp(Webroar::SLASH)
        cached_path = (path.empty? ? Webroar::INDEX : path) + ActionController::Base.page_cache_extension
        
        if file_exist?(path)              # Serve the file if it's there
          serve_file(env)
        elsif file_exist?(cached_path)    # Serve the page cache if it's there
          env[Webroar::PATH_INFO] = cached_path
          serve_file(env)
        else                              # No static file, let Rails handle it
          @rails_app.call(env)
        end
      end      
      
      protected
      
      # For Rails pre Rack (2.3)
      class CgiApp
        def call(env)
          #debugger #for debugging
          request         = ::Rack::Request.new(env)
          response        = ::Rack::Response.new
          
          session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
          cgi             = CGIWrapper.new(request, response)
          
          Dispatcher.dispatch(cgi, session_options, response)
          
          response.finish          
        end
      end
      
      class CGIWrapper < ::CGI
        def initialize(request, response, *args)
          @request  = request
          @response = response
          @args     = *args
          @input    = request.body
          
          super *args
        end
        
        def header(options = "text/html")
          if options.is_a?(String)
            @response['Content-Type']     = options unless @response['Content-Type']
          else
            @response['Content-Length']   = options.delete('Content-Length').to_s if options['Content-Length']
            
            @response['Content-Type']     = options.delete('type') || "text/html"
            @response['Content-Type']    += "; charset=" + options.delete('charset') if options['charset']
            
            @response['Content-Language'] = options.delete('language') if options['language']
            @response['Expires']          = options.delete('expires') if options['expires']
            
            @response.status              = options.delete('Status') if options['Status']
            
            # Convert 'cookie' header to 'Set-Cookie' headers.
            # Because Set-Cookie header can appear more the once in the response body, 
            # we store it in a line break seperated string that will be translated to
            # multiple Set-Cookie header by the handler.
            if cookie = options.delete('cookie')
              cookies = []
              
              case cookie
              when Array then cookie.each { |c| cookies << c.to_s }
              when Hash  then cookie.each { |_, c| cookies << c.to_s }
              else            cookies << cookie.to_s
              end
              
              @output_cookies.each { |c| cookies << c.to_s } if @output_cookies
              
              @response['Set-Cookie'] = [@response['Set-Cookie'], cookies].compact
              # See http://groups.google.com/group/rack-devel/browse_thread/thread/e8759b91a82c5a10/a8dbd4574fe97d69?#a8dbd4574fe97d69                
              if RUBY_VERSION =~ /^1\.8/
                @response['Set-Cookie'].flatten!
              else
                @response['Set-Cookie'] = @response['Set-Cookie'].join("\n")
              end         
              
            end
            
            options.each { |k,v| @response[k] = v }
          end
          
          ""
        end
        
        def params
          @params ||= @request.params
        end
        
        def cookies
          @request.cookies
        end
        
        def query_string
          @request.query_string
        end
        
        # Used to wrap the normal args variable used inside CGI.
        def args
          @args
        end
        
        # Used to wrap the normal env_table variable used inside CGI.
        def env_table
          @request.env
        end
        
        # Used to wrap the normal stdinput variable used inside CGI.
        def stdinput
          @input
        end
        
        def stdoutput
          STDERR.puts "stdoutput should not be used."
          @response.body
        end
      end
    end
  end

end
