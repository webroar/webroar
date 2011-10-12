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
#

require 'rubygems'

module Webroar
  class UserInteraction

    def initialize(options)
      @options = options
      @gem_name = nil
    end
    
    # User input to install WebROaR
    def user_input
      return nil, true, @gem_name if choose_gem_version

      setup_admin_user
      puts "Setting up server specifications ..."
            
      port = read_port
      return port, false, nil
    end
    
    def setup_admin_user
      puts "Setting up server admin panel ..."

      username = read_user_name
      password = read_password

      write_user(username, password)
    end

  private

    def gem_exist?
      print "Checking for any previous installation of WebROaR ... "
      
      if Gem::Specification.respond_to?('find_all_by_name')
        list = Gem::Specification.find_all_by_name(/^webroar$/)
      else
        list = Gem.source_index.find_name(/^webroar$/)
      end

      unless list
        puts "not found."
        return false
      end

      gem_list = list.collect {|gem| gem.version}
      index = 0
      while gem_list[index]
        unless File.exist?(File.join(WEBROAR_ROOT,"..","webroar-#{gem_list[index]}","conf","config.yml"))      
          gem_list.delete_at(index)
        else
          index = index + 1
        end
      end

      if gem_list.length == 0
        puts "not found."
        return false
      end

      puts "found."
      @gem_name = "WebROaR-" + gem_list[gem_list.length - 1].to_s
      return true
    end

    def choose_gem_version

      return false if !@options[:import].nil? and !@options[:import]

      return false unless gem_exist?

      return true if @options[:import]

      require File.join(WEBROAR_ROOT, 'src', 'ruby_lib', 'ruby_interface','version.rb')
      choice_list = ["Import configuration, logs and admin panel data from the previous installation - #{@gem_name}.","No import required, install #{Webroar::SERVER} afresh."]

      puts ""
      puts "Please enter your choice from the options below:"

      choice_list.each_with_index do |item, index|
        puts " #{index+1}. #{item}"
      end
      print "> "

      result = STDIN.gets.chomp("\n")
      return false unless result =~ /^\d+$/
      result = result.to_i
      return true if result == 1
      return false

      #return nil if result < 1 or (gem_names.length - 1) < result
      #return gem_names[result-1]
    end


    def read_user_name
      if !@options[:username] or @options[:username].length < 1
        while(true)
          print "Please enter a username for the administrator account of server's admin panel: "
          username = STDIN.gets.chomp("\n")
          if(username.length < 1)
            #puts "Please enter a username."
            redo
          else
            break
          end
        end
        username
      else
        @options[:username]
      end
    end

    def read_password
      if !@options[:password] or @options[:password].length < 6
        while(true)
          puts "\nPlease enter a password with at least 6 characters." if @options[:password]
          print "Please enter a password(minimum 6 characters) for the administrator account of server's admin panel: "
          system("stty -echo")
          pswd = STDIN.gets.chomp("\n")
          if(pswd.length < 6)
            puts "\nPlease enter a password with at least 6 characters."
            redo
          end
          print "\nConfirm password: "
          re_pswd = STDIN.gets.chomp("\n")
          system("stty echo")
          print "\n"
          if(re_pswd == pswd)
            break
          else
            puts "\nPasswords do not match. Please try again."
            redo
          end
        end
        pswd
      else
        @options[:password]
      end
    end

    def read_port
      if !@options[:port] or !(@options[:port]=~/^\d+$/) or @options[:port].to_i < 1 or @options[:port].to_i > 65535
        while(true)
          puts "\nInvalid port number. Valid port is a number between 1 and 65535. Please try again ..." if @options[:port]
          print "Enter server port (default is 3000): "
          port_s = STDIN.gets.chomp
          if port_s == ""
            port = 3000
            break
          else
            unless port_s=~/^\d+$/
              puts "\nInvalid port number. Valid port is a number between 1 and 65535. Please try again ..."
              redo
            end
            port = port_s.to_i
            if(port < 1 or port > 65535)
              puts "\nInvalid port number. Valid port is a number between 1 and 65535. Please try again ..."
              redo
            else
              break
            end
          end
        end
        port
     else
       @options[:port].to_i
     end
    end

    def write_user(username, pswd)
      info = Array.new
      u = {}
      u['user_name'] = username
      u['password'] = Digest::MD5.hexdigest(pswd)
      info <<= u
      yaml_obj=YAML::dump(info)
      file=File.open(File.join(ADMIN_PANEL_DIR,'config','user.yml'),"w")
      file.puts(yaml_obj)
      file.close
    end

  end #class UserInteraction

end #module Webroar
