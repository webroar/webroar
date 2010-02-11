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
  module UserInteraction
    def choose_gem_version(options)

      return nil if !options[:import].nil? and !options[:import]

      print "Checking for any previous installation of WebROaR ... "
      list = Gem.source_index.find_name(/^webroar$/)

      unless list
        puts "not found."
        return nil
      end

      #gem_names = list.collect {|gem| gem.full_name}
      gem_list = list.collect {|gem| gem.version}
      gem_list.each_with_index do |item, index|
        gem_list.delete(item) if !File.exist?(File.join(WEBROAR_ROOT,"..","webroar-#{item}","conf","config.yml"))
      end

      if gem_list.length == 0
        puts "not found."
        return nil
      end

      puts "found."
      gem_name = "WebROaR-" + gem_list[gem_list.length - 1].to_s

      return gem_name if options[:import]

      require File.join(WEBROAR_ROOT, 'src', 'ruby_lib', 'ruby_interface','version.rb')
      choice_list = ["Import configuration, logs and admin panel data from the previous installation - #{gem_name}.","No import required, install #{Webroar::SERVER} afresh."]

      puts ""
      puts "Please enter your choice from the options below:"

      choice_list.each_with_index do |item, index|
        puts " #{index+1}. #{item}"
      end
      print "> "

      result = STDIN.gets.chomp("\n")
      return nil unless result =~ /^\d+$/
      result = result.to_i
      return gem_name if result == 1
      return nil

      #return nil if result < 1 or (gem_names.length - 1) < result
      #return gem_names[result-1]
    end

    # User input to install WebROaR
    def user_input(options)
      import_from = choose_gem_version(options)
      return nil, true, import_from if import_from

      puts "Setting up server admin panel ..."

      if !options[:username] or options[:username].length < 1
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
        else
        username = options[:username]
      end

      if !options[:password] or options[:password].length < 6
        while(true)
          puts "\nPlease enter a password with at least 6 characters." if options[:password]
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
          if(re_pswd  == pswd)
            write_user(username, pswd)
            break
          else
            puts "\nPasswords do not match. Please try again."
            redo
          end
        end
      else
        write_user(username, options[:password])
      end

      puts "Setting up server specifications ..."

      if !options[:port] or !(options[:port]=~/^\d+$/) or options[:port].to_i < 1 or options[:port].to_i > 65535
        while(true)
          puts "\nInvalid port number. Valid port is a number between 1 and 65535. Please try again ..." if options[:port]
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
        else
        port = options[:port].to_i
      end
      return port, false, nil
    end  
  end
end
