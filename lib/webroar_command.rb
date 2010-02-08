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

ADMIN_PANEL_ROOT = File.join(WEBROAR_ROOT, 'src', 'admin_panel').freeze

class WebroarCommand

  def remove_logrotate  # Clear log files
    if CheckUser.new.check == 0
      if RUBY_PLATFORM =~ /linux/
        print "Removing log rotate file ..."
        file = File.join('','etc','logrotate.d','webroar')
        if File.exists?(file)
          File.delete(file)
        end
      end
      if RUBY_PLATFORM =~ /darwin/
        print "Removing log rotate entry ..."
        # read file into an array
        f = File.open("/etc/newsyslog.conf")
        saved = File.open("tmp.conf", "a")
        results = f.readlines
        # Is there a way to remove everything that's been read here?
        f.close

        results.each do |sending|
          if !sending.include?"webroar"
            saved.puts("#{sending}")
          end
        end

        # Close the archive file
        saved.close

        FileUtils.mv("tmp.conf", "/etc/newsyslog.conf")
      end

      puts " done."
    end
  end

  def clear(options, args)  # Clear log files
    if CheckUser.new.check == 0
      print "Clearing log files ..."
      log_file_pattern = File.join('','var','log','webroar','*.log')
      log_files = Dir.glob(log_file_pattern)
      for file in log_files
        if File.exists?(file)
          File.truncate(file, 0)
        end
      end
      puts " done."
    end
  end

  def start_starling    
    print "Starting message queue server ..."
    starling_conf_file = File.join(WEBROAR_ROOT, 'conf', 'starling_server_config.yml')
    pid_file = YAML.load(File.open(starling_conf_file))["starling"]["pid_file"]
    pid = File.read(pid_file).chomp.to_i rescue nil    
    if pid
      system("kill -0 #{pid}")
      if $? == 0
        puts " already running."
        return :running
      end
    end
    
    filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
    log_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["log_file"]
    cmd = "starling -f #{starling_conf_file} >> #{log_file} 2>>#{log_file}"
    system(cmd)
    if $? == 0
      puts " done."
      :up
    else
      cmd = "starling -f #{starling_conf_file} >> analyzer.log 2>>analyzer.log"
      system(cmd)
      if $? == 0
        puts " done."
        :up
      else
        puts " failed."
        puts "'Analytics' and 'Exception Notification' features would not work. Please refer '#{log_file}' for details."
        :down
      end
    end
  end

  def start_webroar
    puts "Initiating WebROaR startup sequence ..."
    if File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-head")) && File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-worker"))
      starling_status = start_starling
      server_status = :down
      puts "Starting webroar-head process ..."
      pid_file = PIDFILE
      pid = File.read(pid_file).chomp.to_i rescue nil
      if !pid
        system("#{WEBROAR_BIN_DIR}/webroar-head #{WEBROAR_ROOT}")
      else
        system("kill -0 #{pid}")
        if $? == 0
          puts " already running."
          server_status = :running
        else
          system("#{WEBROAR_BIN_DIR}/webroar-head #{WEBROAR_ROOT}")
        end
      end
      
      if server_status == :down
        if $? == 0
          filename = File.join(WEBROAR_ROOT, 'conf', 'config.yml')
          apps_spec = YAML.load(File.open(filename))["Application Specification"]
          sleep_time = 1
          sleep_time += apps_spec.size if apps_spec
          sleep(sleep_time*1.5)
          puts "Head process started successfully."          
        else
          puts "An error occurred while starting head process. Please refer '#{WEBROAR_LOG_FILE}' for details."
          if starling_status == :up
            filename = File.join(WEBROAR_ROOT, 'conf', 'starling_server_config.yml')
            pid_file = YAML.load(File.open(filename))["starling"]["pid_file"]
            puts "Aborting startup sequence"
            print "Stopping starling message queue server ..."
            pid = File.read(pid_file).chomp.to_i rescue nil
            if pid
              system("kill -INT #{pid} 2>/dev/null")
              if $? == 0
                puts " done."
              else
                puts " failed."
              end
            else
              puts 'Failed to retrieve pid for the starling message queue server process. Unable to kill it.'
            end
          end
          return
        end
      end
      
      analyzer_status = :down
      if starling_status == :up or starling_status == :running
        filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
        log_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["log_file"]
        cmd = "webroar-analyzer >> #{log_file} 2>>#{log_file}"
        print "Starting webroar-analyzer process ..."        
        pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
        pid = File.read(pid_file).chomp.to_i rescue nil
        if pid
          system("kill -0 #{pid} 2>/dev/null")
          if $? == 0
            puts " already running."
            analyzer_status = :running            
          end
        end
        if analyzer_status == :down          
          system(cmd)          
          if $? == 0
            puts " done."           
            analyzer_status = :up            
          else
            # one more try(if /var/log/webroar/ not exists) trying to open analyzer.log in current dir
            cmd = "webroar-analyzer >> analyzer.log 2>>analyzer.log"
            system(cmd)            
            if $? == 0
              puts " done."
              analyzer_status = :up              
            else
              puts " failed."
              puts "'Analytics' and 'Exception Notification' features would not work. Please refer '#{log_file}' for details."
              analyzer_status = :down              
            end
          end
        end        
      end
      
      if analyzer_status == :down
        puts "Server started but 'Analytics' and 'Exception Notification' features would not work."
      elsif server_status == :running and analyzer_status == :running 
        puts "Server already running."
      else
        puts "Server started successfully."
      end
      
    else
      puts "WebROaR is not installed on this machine. Please run *sudo webroar install* to install it."
    end
  end

  def start_application(args)
    # Start the application
    count = 1
    while (count < args.length)
      ctl = Control.new(args[count])      									
      begin
        reply, err_log = ctl.add
        # reply = nil indicate success
        if reply == nil
          puts "Application '#{args[count]}' started successfully."
        else
          puts reply
        end
        puts "\n\e[31m" + err_log + "\e[0m" if err_log
      rescue Exception => e
        puts e
        puts e.backtrace
        puts "An error occurred while sending 'start' request for the application '#{args[count]}'."
      end      
      count += 1
    end
  end

  def start(options, args)
    if CheckUser.new.check == 0
      if args.length == 1
        start_webroar
      else
        start_application(args)
      end
    end
  end

  def stop_webroar
    begin
      filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
      pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
      if !(File.exists?(PIDFILE) or File.exists?(pid_file))
        puts "WebROaR is not running."
        return
      end
      print 'Stopping webroar-head ...'
      pid_file = PIDFILE
      pid = File.read(pid_file).chomp.to_i rescue nil
      if pid
        system("kill -INT #{pid} 2>/dev/null")
        if $? == 0
          puts " done."
        else
          puts " failed."
        end
      else
        puts " failed."
        puts 'Failed to retrieve pid for the server process. Unable to kill it.'
      end

      filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
      pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
      print "Stopping webroar-analyzer process ..."
      pid = File.read(pid_file).chomp.to_i rescue nil
      if pid
        system("kill -INT #{pid} 2>/dev/null")
        if $? == 0
          puts " done."
        else
          puts " failed."
          puts "Please refer the log file for details."
        end
      else
        puts " failed."
        puts 'Failed to retrieve pid for webroar-analyzer process. Unable to kill it.'
      end
      sleep(1)
      # Remove all temporary files
      FileUtils.rm Dir.glob('/tmp/webroar_*')
    rescue => err
      puts err
      puts err.backtrace
    end
  end

  def stop_application(args)
    count = 1
    while (count < args.length)
      ctl = Control.new(args[count])  
      begin
        reply, err_log = ctl.delete
        # reply = nil indicate success
        if reply == nil
          puts "Application '#{args[count]}' stopped successfully."
        else
          puts reply
        end
        puts "\n\e[31m" + err_log + "\e[0m" if err_log
      rescue Exception => e
        puts e
        puts e.backtrace
        puts "An error occurred while sending 'stop' request for the application '#{args[count]}'."
      end      
      count += 1
    end
  end

  def stop(options, args)
    if CheckUser.new.check == 0
      if args == nil or args.length == 1
        stop_webroar
      else
        stop_application(args)
      end
    end

  end

  def restart_webroar
    puts "Restarting WebROaR ..."
    filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
    pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
    if File.exists?(PIDFILE) or File.exists?(pid_file)
      stop_webroar
      system("sleep 1")
    end
    start_webroar
  end

  def restart_application(args)
    count = 1
    while (count < args.length)
      ctl = Control.new(args[count])      
      begin
        reply, err_log = ctl.restart
        # reply = nil indicate success
        if reply == nil
          puts "Application '#{args[count]}' restarted successfully."
        else
          puts reply
        end
        puts "\n\e[31m" + err_log + "\e[0m" if err_log
      rescue Exception => e
        puts e
        puts e.backtrace
        puts "An error occurred while sending 'restart' request for the application '#{args[count]}'."
      end      
      count += 1
    end
  end

  def restart(options, args)
    if CheckUser.new.check == 0
      if args.length == 1
        restart_webroar
      else
        restart_application(args)
      end
    end
  end

  def load_files(files)
    unloaded = Array.new
    files.each do |f|
      begin
        require f
      rescue NameError
        unloaded << f
        next
      end
    end
    unloaded.each do |f|
      require f
    end
  end

  def remove(options, args)
    return if CheckUser.new.check != 0
    if args.count < 2
      puts "Application name is missing."
      return
    end

    gem 'activesupport', '>= 2.3.5'
    gem 'activerecord', '>= 2.3.5'
    require 'active_record'

    files = Dir.glob(File.join(ADMIN_PANEL_ROOT, 'app', 'models', "{app,pseudo_model,application_specification,server_specification}.rb"))
    files << File.join(ADMIN_PANEL_ROOT, 'config','initializers','application_constants.rb')
    files << File.join(ADMIN_PANEL_ROOT, 'lib','yaml_writer.rb')

    load_files(files)

    reply = App.stop(args[1])
    if reply.nil?
      puts "Application '#{args[1]}' removed successfully."
      ApplicationSpecification::remove(args[1]) if reply.nil?
    else
      puts reply
    end

  end

  def add(options, args)
    return if CheckUser.new.check != 0
    if args.count < 2
      puts "Application name is missing."
      return
    end
    gem 'activesupport', '>= 2.3.5'
    gem 'activerecord', '>= 2.3.5'
    require 'active_record'

    params = {:app_id=>nil, :name=>nil, :host_names=>nil, :baseuri=>nil, :resolver=>nil, :path=>nil, :run_as_user=>nil, :type1=>'Rails', :analytics=>'Disabled', :environment=>'production', :min_worker=>'4', :max_worker=>'8'}

    files = Dir.glob(File.join(ADMIN_PANEL_ROOT, 'app', 'models', "{app,pseudo_model,application_specification,server_specification}.rb"))
    files << File.join(ADMIN_PANEL_ROOT, 'config','initializers','application_constants.rb')
    files << File.join(ADMIN_PANEL_ROOT, 'lib','yaml_writer.rb')

    load_files(files)

    options[:name] = args[1]

    params = params.merge(options)

    application_specification = ApplicationSpecification.new(params)

    if application_specification.save
      application_specification.write
      app_name = params[:name]
      err_obj = nil
      reply = nil
      reply, err_obj = App.start(app_name)
      #reply = nil indicate success
      if(err_obj)
        puts err_obj
        puts err_obj.backtrace
        application_specification.remove
      end
      puts "Application '#{app_name}' added successfully." if reply == nil
      if reply
        puts reply
        application_specification.remove
      end
    else
      application_specification.errors.each_full{|msg| puts msg }
    end
    
  end
  
end
