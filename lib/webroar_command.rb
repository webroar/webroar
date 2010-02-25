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

# Basic WebROaR commands
class WebroarCommand

  # Clear log files
  def clear()
    return unless CheckUser.check
    print "Clearing log files ..."
    log_file_pattern = File.join('','var','log','webroar','*.log')
    log_files = Dir.glob(log_file_pattern)
    for file in log_files
      File.truncate(file, 0) if File.exists?(file)
    end
    puts " done."
  end

  # Start/Stop/Restart Command
  def operation(args, op)
     return unless CheckUser.check
    (args.nil? or args.length == 1) ? server_operation(op) : application_operation(args, op)
  end

  # Stop and remove the application
  def remove(args)
    return unless CheckUser.check
    if args.length < 2
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

    reply, err_log = App.stop(args[1])
    ApplicationSpecification::remove(args[1]) if reply.nil?
    
    puts reply ? reply : "Application '#{args[1]}' removed successfully."
    puts "\n\e[31m" + err_log + "\e[0m" if err_log

  end

  # Add and start the application
  def add(options, args)
    return unless CheckUser.check
    if args.length < 2
      puts "Application name is missing."
      return
    end

    sockFile = File.join("","tmp","webroar.sock")

    unless File.exist?(sockFile)
      puts "Either the server is not started or 'webroar.sock' file is deleted."
      return
    end

    gem 'activesupport', '>= 2.3.5'
    gem 'activerecord', '>= 2.3.5'
    require 'active_record'

    params = {:app_id => nil,
      :name => args[1],
      :host_names => nil,
      :baseuri => nil,
      :resolver => options[:resolver],
      :path => options[:path],
      :run_as_user => options[:run_as_user],
      :type1 => options[:type1] ? options[:type1] : 'Rails',
      :analytics => options[:analytics] ? options[:analytics] : 'Disabled',
      :environment => options[:environment] ? options[:environment] : 'production',
      :min_worker => options[:min_worker] ? options[:min_worker] : '4',
      :max_worker => options[:max_worker] ? options[:max_worker] : '8'}

    files = Dir.glob(File.join(ADMIN_PANEL_ROOT, 'app', 'models', "{app,pseudo_model,application_specification,server_specification}.rb"))
    files << File.join(ADMIN_PANEL_ROOT, 'config','initializers','application_constants.rb')
    files << File.join(ADMIN_PANEL_ROOT, 'lib','yaml_writer.rb')

    load_files(files)

    application_specification = ApplicationSpecification.new(params)

    if application_specification.save
      application_specification.write
      application_specification.errors.each_full{|msg| puts msg }
      reply, err_log = App.start(params[:name])
      #reply = nil indicate success
      puts reply ? reply : "Application '#{params[:name]}' added successfully."
      puts "\n\e[31m" + err_log + "\e[0m" if err_log
      application_specification.remove if (err_log or reply)
    else
      application_specification.errors.each_full{|msg| puts msg }
    end
    
  end

  private

  # Start the server
  def start_webroar
    puts "Initiating WebROaR startup sequence ..."
    if File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-head")) && File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-worker"))
      starling_status = start_starling
      server_status = :down
      puts "Starting webroar-head process ..."
      pid_file = PIDFILE
      pid = File.read(pid_file).chomp.to_i rescue nil
      unless pid
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
            kill_process(pid)
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

  # Start starling process
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
    system("starling -f #{starling_conf_file} >> #{log_file} 2>>#{log_file}")
    if $? == 0
      puts " done."
      :up
    else
      system("starling -f #{starling_conf_file} >> analyzer.log 2>>analyzer.log")
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

  # Stop the server
  def stop_webroar
    begin
      filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
      pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
      if !(File.exists?(PIDFILE) or File.exists?(pid_file))
        puts "WebROaR is not running."
        return
      end
      print 'Stopping webroar-head ...'
      pid = File.read(PIDFILE).chomp.to_i rescue nil
      kill_process(pid)

      filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
      pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]
      print "Stopping webroar-analyzer process ..."
      pid = File.read(pid_file).chomp.to_i rescue nil
      kill_process(pid)
      sleep(1)

      # Remove all temporary files
      FileUtils.rm Dir.glob('/tmp/webroar_*')
    rescue => err
      puts err
      puts err.backtrace
    end
  end

  # Restart the server
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

  def kill_process(pid)
    if pid
      system("kill -INT #{pid} 2>/dev/null")
      puts $? == 0 ? " done." : " failed."
    else
      puts " failed."
      puts "Failed to retrieve pid. Unable to kill it."
    end
  end

  # Load the list of files
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

  # Server start/stop/restart
  def server_operation(op)
    case op
    when 'start'
      start_webroar
    when 'stop'
      stop_webroar
    when 'restart'
      restart_webroar
    end
  end

  # Application start/stop/restart
  def application_operation(args, op)
    for i in 1..args.length-1
      begin

        case op
        when 'start'
          reply, err_log = Control.new(args[i]).add
          # reply = nil indicate success
          puts reply ? reply : "Application '#{args[i]}' started successfully."
        when 'stop'
          reply, err_log = Control.new(args[i]).delete
          puts reply ? reply : "Application '#{args[i]}' stopped successfully."
        when 'restart'
          reply, err_log = Control.new(args[i]).restart
          puts reply ? reply : "Application '#{args[i]}' restarted successfully."
        else
          return
        end

        puts "\n\e[31m" + err_log + "\e[0m" if err_log
      rescue Exception => e
        puts e
        puts e.backtrace
        puts "An error occurred while sending '#{op}' request for the application '#{args[i]}'."
      end
    end
  end
  
end
