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

require "fileutils"
require 'user_interaction'

class Installer
  include Webroar
  #include Webroar::UserInteraction

  CONFIG_HEADER = %{
######################################################################################
#                             WebROaR Configuration file
######################################################################################

######################################################################################
# Configuration file has three YAML formatted components
# Order of components does not matter.
#   a) Server Specification
#        Elements:
#          1) Server Port(optional)(default port = 3000)
#          2) Minimum number of workers(optional)(default min_worker = 4)
#          3) Maximum number of workers(optional)(default max_worker = 8)
#          4) Logging level(optional)(default log_level = SEVERE)
#          5) SSL Specification(optional)
#             It defines SSL specification.
#             Parameters:
#               I) SSL Support(optional)(values must be 'enabled' or 'disabled'(default))
#              II) SSL Certificate File(optional)(Path to SSL certificate file. Default is empty)
#             III) SSL Key File(optional)(Path to SSL key file. Default is empty)
#              IV) SSL Port(optional)(Default port number 443)
#          6) Access log(optional)(values must be 'enabled'(default) or 'disabled')
#        Order of the above elements does not matter.
#        Example:
#          Server Specification:
#            port: 3000
#            min_worker: 4
#            max_worker: 8
#            log_level: SEVERE
#            access_log: enabled
#            SSL Specification:
#              ssl_support: enabled
#              certificate_file: /home/smartuser/ca-cert.pem
#              key_file: /home/smartuser/ca-key.pem
#              ssl_port: 443
#
#   b) Application Specification (optional)
#        Elements:
#          1) Application name(mandatory)
#          2) Application baseuri(optional)
#          3) Application path(mandatory)
#          4) Application type(mandatory)(example rails or rack)
#          5) Application environment(optional)(default environment = production)
#          6) Application analytics(mandatory)(values must be 'enabled' or 'disabled')
#          7) Minimum number of workers(optional)(default is 'Server Specification/min_worker')
#          8) Maximum number of workers(optional)(default is 'Server Specification/max_worker')
#          9) Logging level(optional)(default is 'Server Specification/log_level')
#         10) Run as user (mandatory)
#         11) Hostnames(optional)
#         12) Environment Variable(optional)
#             It defines environment variables which can be used in the deployed application. It take following parameter.
#               I) set_env(optional)(Value is key-value pair separated by equal sign('=') e.g. LOG_DIR=/var/log/webroar)             
#        Order of the above elements does not matter.
#        Base-uri 'admin-panel' is reserved for 'Admin Panel'.
#        Either host_names or baseuri(not both) must present to resolve HTTP request.
#        Hostnames can have multiple values, each separated by spaces.(e.g. host_names: server.com server.co.in)
#        Hostnames can be defined using wildcard(*), but wildcard can only be at start of name or at end of name (valid hostnames are (i) *.server.com (ii) www.server.* (iii) *.server.*).
#        Prefix Hostname with tilde(~), if wildcard is used in defining Hostname. e.g. (i) ~*.server.com  (ii) ~www.server.*  (iii) ~*.server.*
#        Example with baseuri:
#          Application Specification:
#            - name: Mephisto
#              baseuri: /blog
#              path: /home/smartuser/work/rails_workspace/mephisto
#              type: rails
#              run_as_user: smartuser
#              analytics: enabled
#              environment: production
#              min_worker: 2
#              max_worker: 5
#              log_level: SEVERE
#              environment_variables: 
#                - set_env: LOG_DIR=/var/log/webroar
#                - set_env: TMP_DIR=/tmp
#        Example with host_names:
#          Application Specification:
#            - name: Mephisto
#              host_names: myblog.com ~*.myblog.com
#              path: /home/smartuser/work/rails_workspace/mephisto
#              type: rails
#              run_as_user: smartuser
#              analytics: enabled
#              environment: production
#              min_worker: 2
#              max_worker: 5
#              log_level: SEVERE
#              environment_variables: 
#                - set_env: LOG_DIR=/var/log/webroar
#                - set_env: TMP_DIR=/tmp
#
#  (c) Headers (optional)
#        It allows adding or changing the Expires and Cache-Control in the response headers for static assets (e.g. *.js, *.gif etc). 
#        Elements:
#          1) Expires header for all static assets (optional) (default is 'off')
#          2) Specific expires header for specific file types (optional)
#             Elements:
#                I) File Extensions(mandatory)
#               II) Expires value(mandatory) (No of seconds)
#        Possible value for expires is off or no. of seconds. 
#        Example:
#          Headers:
#            expires: 3600
#            expires_by_type:
#            - ext: png, jpg, gif
#              expires: 31536000
#
#  (d) Encoding (optional)
#        It allows (deflate) encoding of static assets.
#        Elements:
#          1) Regex value for supported Content-Type (optional) (default is 'text|xml')
#          2) Regex value for supported Used-Agent (optional) (default is '.*')
#          3) Range of Content-Length (optional)
#             Elements:
#                I) Lower limit of Content-Length (optional) (default is 1024 i.e. 1KB) 
#               II) Upper limit of Content-Length (optional) (default is 12328960 i.e. 10MB)
#        Example:
#          Encoding:
#            Content-Type: text|xml|javascript
#            User-Agent: .*
#            Size Limit:
#              lower_limit: 2094
#              upper_limit: 12328960
#
######################################################################################
  }
             
  ADMIN_USER_FILE = File.join(ADMIN_PANEL_DIR,'config','user.yml')
  WEBROAR_CONFIG_FILE = File.join(WEBROAR_ROOT, 'conf', 'config.yml')
  DB_CONFIG_FILE = File.join(ADMIN_PANEL_DIR, 'config', 'database.yml')
  if RUBY_PLATFORM =~ /linux/
    REQUIRED_DEPENDENCIES = [
      Dependencies::Ruby,
      Dependencies::LibRuby,
      Dependencies::Ruby_OpenSSL,
      Dependencies::RubyZlib,
      Dependencies::Ruby_DevHeaders,
      Dependencies::RubyGems,
      Dependencies::GCC,
      Dependencies::Make,
      Dependencies::LibSqlite,
      Dependencies::Sqlite_DevHeaders,
      Dependencies::Starling,
      Dependencies::Gnutls,
      Dependencies::Zlib,
      Dependencies::Regex
    ]
  end
  
  if RUBY_PLATFORM =~ /darwin/
    REQUIRED_DEPENDENCIES = [
      Dependencies::Ruby,
      Dependencies::LibRuby,
      Dependencies::Ruby_OpenSSL,
      Dependencies::RubyZlib,
      Dependencies::Ruby_DevHeaders,
      Dependencies::RubyGems,
      Dependencies::GCC,
      Dependencies::Make,
      Dependencies::Starling,
      Dependencies::Xcode,
      Dependencies::Gnutls,
      Dependencies::Zlib,
      Dependencies::Regex
    ]
  end

  def initialize
    @options = nil
    @ssl = false
    @import = false
    @port = 0
    @err_msg = nil
    @zlib = true
    @regex = true
  end

  # Install the server
  def install(options)
    
    begin
      return -1 unless CheckUser.check
      @options = options
      
      str = set_install_options
  
      check_dependencies || exit(1)
      
      str << " zlib=yes" if @zlib
      str << " regex=yes" if(@zlib and @regex)
        
      @port, @import, gem_name = UserInteraction.new(@options).user_input
      @port = import_files(gem_name) if @import
      write_server_port if !@import
        
      create_dirs
      return -1 unless compile_code(str)
      return -1 unless install_server
      
  
      # Stop WebROaR if already running.
      WebroarCommand.new.operation(nil, "stop") if File.exist?(PIDFILE)
  
      # Start WebROaR
      puts"Starting WebROaR ... "
      WebroarCommand.new.operation(nil, "start")
      
      install_msg(false)
      puts "Warning: " + @err_msg if @err_msg
    rescue Exception=>e
      File.open(File.join(WEBROAR_ROOT, "install.log"), "a+") do |f|
        f.puts e.class.name
        f.puts e.backtrace
      end
    end
  end

  # Start test cases
  def test(options)  # run test-suite comprises of unit test, functional test, admin-panel test, load test
    return -1 unless CheckUser.check
    @options = options

    # stopping the server.. its get started on installation.
    puts "Please make sure you have made relevant changes in conf/test_suite_config.yml"
    cmd = "webroar stop"
    system(cmd)
    str = ""
    
    str += "load_test=yes " if @options[:load_test]
    str += "debug_build=yes " if @options[:debug_build]
    str += "no_report=yes " if @options[:no_report]
    str += "report_dir=#{@options[:report_dir] ? @options[:report_dir] : File.join(WEBROAR_ROOT,'report')} "
    
    Dir.chdir(WEBROAR_ROOT)
    system("rake all_test #{str}")
  end

  # Uninstall the server
  def uninstall
    return -1 unless CheckUser.check
      
    if !File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-head")) or !File.exist?(File.join(WEBROAR_BIN_DIR,"webroar-worker"))
      puts "WebROaR is already uninstalled."
      return
    end

    stop_server
    return -1 unless remove_executables
    return -1 unless remove_admin_panel
    remove_log_files
    remove_service_script

  end
  
  def version    
    require File.join(WEBROAR_ROOT, 'src', 'ruby_lib', 'ruby_interface','version.rb')
    puts "#{Webroar::SERVER}"
  end
  
  private

  def remove_service_script
    if RUBY_PLATFORM =~ /linux/
      printf "Removing service script ... "
      destroy_service()
      puts "done."
    end
  end

  def remove_log_files
    print "Removing files ...\n"
    log_rotate(false)
    dirs = [File.join('','var','log','webroar')]
    dirs.each do |dir|
      file_pattern = File.join(dir, '*')
      files = Dir.glob(file_pattern)
      files.each do |file|
        File.delete(file) if File.exists?(file)
      end
      Dir.rmdir(dir) if File.exists?(dir)
    end
  end

  def remove_admin_panel
    print "Removing admin panel application database ..."
    begin
      Dir.chdir(ADMIN_PANEL_DIR)
      system("rake db:drop >>#{WEBROAR_ROOT}/uninstall.log 2>>#{WEBROAR_ROOT}/uninstall.log")
      if($?==0)
        puts " done."
        puts "WebROaR uninstalled successfully."
      else
        puts "An error occurred while removing the database. Please refer 'uninstall.log' for details."
        return false
      end
    rescue Exception => e
      puts e
      puts e.backtrace
      puts "An error occurred while removing the database. Please refer 'uninstall.log' for details."
      return false
    end
    return true
  end

  def remove_executables
    Dir.chdir(WEBROAR_ROOT)
    print "Removing executables ..."
    # removing softlink also
    remove_softlink('starling')
    remove_softlink('webroar')
    remove_softlink('webroar-analyzer')
    system("rake clobber >uninstall.log 2>>uninstall.log")
    unless ($?==0)
      puts "An error occurred while removing the files. Please refer 'uninstall.log' for details."
      return false
    end

    puts " done."
    return true
  end

  def stop_server
    # Stop the server
    filename = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
    pid_file = YAML.load(File.open(filename))["webroar_analyzer_script"]["pid_file"]

    WebroarCommand.new.operation(nil, "stop") if File.exists?(PIDFILE) or File.exists?(pid_file)
  end

  def log_rotate_linux(add)
    file = File.join('','etc','logrotate.d','webroar')

    if add
      # Create log rotate script
      file=File.open(file,"w")
      logrotate_string = get_logrotate()
      file.puts(logrotate_string)
      file.close

      print "Generating service script ..."
      # Add service script in '/etc/init.d/' folder
      if create_service()
        puts " done."
      else
        puts " failed."
        return "The server could not be installed as a service on this system. Unfortunately, you would have to set it up as a service yourself."
      end
    else
      print "Removing log rotate file ..."
      File.delete(file) if File.exists?(file)
    end
    return nil
  end

  def log_rotate_darwin(add)
     print "Removing log rotate entry ..." unless add
     # read file into an array
     f = File.open("/etc/newsyslog.conf")
     results = f.readlines
     f.close

     saved = File.open("tmp.conf", "a")
     # Is there a way to remove everything that's been read here?

     results.each do |sending|
       saved.puts("#{sending}") unless sending.include?"webroar"
     end

     saved.puts("/var/log/webroar/*.log   644  5     10   *     GJ") if add

     # Close the archive file
     saved.close

     FileUtils.mv("tmp.conf", "/etc/newsyslog.conf")
  end

  # Add/Remove log rotate script
  def log_rotate(add = true)

    if RUBY_PLATFORM =~ /linux/
      retval = log_rotate_linux(add)
      return retval unless retval.nil?
    end

    log_rotate_darwin(add) if RUBY_PLATFORM =~ /darwin/
      
    puts " done." unless add
    return nil if add
  end

  def write_server_port
    info = Array.new
    if @ssl
      s = {'port' => @port, 'min_worker' => 4, 'max_worker' => 8, 'log_level' => "SEVERE",'access_log'=>'enabled','SSL Specification' => {'ssl_port' => 443, 'ssl_support' => "disabled", 'certificate_file' => nil, 'key_file' => nil}}
    else
      s = {'port' => @port, 'min_worker' => 4, 'max_worker' => 8, 'log_level' => "SEVERE",'access_log'=>'enabled'}
    end
    info = {'Server Specification' => s}
    write_server_config_file(info)
  end

  def write_server_config_file(info)
    yaml_obj=YAML::dump(info)
    file=File.open(WEBROAR_CONFIG_FILE,"w")
    file.puts(CONFIG_HEADER)
    file.puts(yaml_obj)
    file.close
  end

  # Check the dependency
  def check_dependencies
    puts "Checking for the dependencies ..."
    failed_dependencies = []
    
    REQUIRED_DEPENDENCIES.each do |dep|
      if (dep.name=="gnutls/gnutls.h" and @ssl) or dep.name != "gnutls/gnutls.h"
        print "Checking for #{dep.name}........"
        status = dep.find(@options)
        status = "\e[31mnot found\e[0m." if status == nil
        puts status
        if status =~ /.*not found.*/
          failed_dependencies[failed_dependencies.size] = dep.name
          #puts "Server could not be installed. Please see the 'user guide' for the list of prerequisites."
          #TODO: Check for all the dependencies and list them with their appropriate solutions.
          #return false
        end
      end
    end
    
    @zlib = false if failed_dependencies.include?(Dependencies::Zlib.name)
    failed_dependencies.delete(Dependencies::Zlib.name)

    @regex = false if failed_dependencies.include?(Dependencies::Regex.name)
    failed_dependencies.delete(Dependencies::Regex.name)

    if( failed_dependencies.size > 0)
      puts "The following dependencies required for installation could not be found:"
      print "\e[31m"
      failed_dependencies.each do |dependency|
        puts dependency
      end
      
      puts "\e[0mPlease refer the user guide for the list of prerequisites."
      puts "Sorry, WebROaR could not be installed on this machine."
      return false
    end
    
    unless @zlib
      puts "\n\e[31mThe installation continue without supporting static assets encoding.\e[0m"
      puts ""
    else
      unless @regex
        puts "\n\e[31mThe static asstes endcoding supported without Regex validations.\e[0m"
        puts ""
      end
    end

    return true
  end 

  def check_exe_file(file)
    paths = ENV['PATH'].split(":")
    flag = false
    paths.length.times do |i|
      if File.executable?(File.join(paths[i], file))
        flag = true
        break
      end
    end
    return flag
  end

  def create_service_links(script_file)
    create_service_link("0", 'K15webroar', script_file)
    create_service_link("1", 'K15webroar', script_file)
    create_service_link("6", 'K15webroar', script_file)
    create_service_link("2", 'S85webroar', script_file)
    create_service_link("3", 'S85webroar', script_file)
    create_service_link("4", 'S85webroar', script_file)
    create_service_link("5", 'S85webroar', script_file)
  end

  def get_service_dir
    service_dir = "init.d"

    system("find /etc/ -name #{service_dir} > /tmp/search_result 2>>#{WEBROAR_ROOT}/install.log")

    if !File.size?("/tmp/search_result")
      service_dir = "rc.d"
      system("find /etc/ -name #{service_dir} > /tmp/search_result 2>>#{WEBROAR_ROOT}/install.log")
    end

    return nil if !File.size?("/tmp/search_result")

    file = File.open("/tmp/search_result")
    line = file.readline.chomp
    file.close()

    return line
  end

  def create_service
    script = nil
    script_file = nil

    service_dir = get_service_dir

    return false if service_dir == nil

    if(check_exe_file("chkconfig"))
      script = get_service_script("# chkconfig: 2345 85 15")
    else
      script = get_service_script()
    end

    script_file = File.join("#{service_dir}",'webroar')

    file = File.open(script_file,"w")
    file.puts(script)
    file.close

    system("chmod +x #{script_file} 2>>#{WEBROAR_ROOT}/install.log")

    # Service script is created sucessfully. So return true in all the cases.

#    return false if !create_service_link("0", 'K15webroar', script_file)
#    return false if !create_service_link("1", 'K15webroar', script_file)
#    return false if !create_service_link("6", 'K15webroar', script_file)
#    return false if !create_service_link("2", 'S85webroar', script_file)
#    return false if !create_service_link("3", 'S85webroar', script_file)
#    return false if !create_service_link("4", 'S85webroar', script_file)
#    return false if !create_service_link("5", 'S85webroar', script_file)

    create_service_links(script_file)

    return true

  end

  def get_service_script(start_stop_level="# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6")
    return "#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          WebROaR
    "+start_stop_level+"
# Short-Description: Start and stop the WebROaR application server.
# Description:       Controls the WebROaR server using \"webroar\" command.
### END INIT INFO
#

NAME=webroar

case \"$1\" in
  start)
  webroar start
  ;;
  stop)
  webroar stop
  ;;
  restart)
  webroar restart
  ;;
  force-reload)
  webroar restart
  ;;
  *)
  N=/etc/init.d/$NAME
  echo \"Usage: $N {start|stop|restart|force-reload}\" >&2
  exit 1
  ;;
esac

exit 0"
  end

  def create_service_link(level, link_name, script_file)
    system("find /etc/ -name rc#{level}.d > /tmp/search_result 2>>#{WEBROAR_ROOT}/install.log")

    return false if !File.size?("/tmp/search_result")

    file = File.open("/tmp/search_result")
    line = file.readline.chomp
    file.close()

    return false if line == nil

    link_file = File.join(line,link_name)

    if script_file != nil and !File.symlink?(link_file)
      system("ln -s #{script_file} #{link_file} >>#{WEBROAR_ROOT}/install.log 2>>#{WEBROAR_ROOT}/install.log")
    end

    return true
  end

  def destroy_service
    system("find /etc/ -name *webroar > /tmp/search_result")
    File.open("/tmp/search_result").each{|line|
      system("rm #{line}")
    }
  end

  def get_logrotate
    return "/var/log/webroar/*.log {\n"\
      "\tdaily\n"\
      "\tmissingok\n"\
      "\trotate 52\n"\
      "\tcompress\n"\
      "\tdelaycompress\n"\
      "\tnotifempty\n"\
      "\tcopytruncate\n"\
      "\}"
  end
  
  def import_server_configuration(import_dir)
    unless File.exist?(File.join(import_dir,"conf","config.yml"))
      @port = 3000
      write_server_port
      return
    end

    info = YAML.load(File.open(File.join(import_dir,"conf","config.yml")))
    ssl = info['Server Specification']['SSL Specification'] if info and info['Server Specification'] and info['Server Specification']['SSL Specification']

    # Check for ssl support
    if @ssl
      info['Server Specification']['SSL Specification'] = {'ssl_port' => 443, 'ssl_support' => "disabled", 'certificate_file' => nil, 'key_file' => nil} if ssl.nil?
    else
      info['Server Specification'].delete('SSL Specification') unless ssl.nil?
    end

    # Write server configuration file.
    write_server_config_file(info)
  end

  def import_files(gem_name)
    print "Importing configuration, logs and admin panel data from the previous #{gem_name} install ... "
    require File.join(WEBROAR_ROOT, 'src', 'ruby_lib', 'ruby_interface','version.rb')

    # Get import directory path
    import_dir = File.expand_path(File.join(WEBROAR_ROOT, "..", gem_name.downcase))

    import_server_configuration(import_dir)

    if Webroar::SERVER.downcase == gem_name.downcase
      puts "done."
      return YAML.load(File.open(WEBROAR_CONFIG_FILE))["Server Specification"]["port"]
    end

    FileUtils.copy(File.join(import_dir,"src","admin_panel","config","user.yml"), ADMIN_USER_FILE)
    FileUtils.copy(File.join(import_dir,"src","admin_panel","config","database.yml"), DB_CONFIG_FILE)
    configuration = YAML.load(File.open(DB_CONFIG_FILE))["production"]
    if configuration['adapter'] == 'sqlite3' and configuration['database'][0,1] != "/"
      db = File.join(import_dir, "src", "admin_panel", configuration['database'])
      FileUtils.copy(db, File.join(ADMIN_PANEL_DIR, configuration['database'])) if File.exist?(db)
    end
    puts "done."
    return YAML.load(File.open(WEBROAR_CONFIG_FILE))["Server Specification"]["port"]
  end

  def set_install_options
    @ssl = false
    str = ""

    if @options[:ssl]
      @ssl = true
      str << "ssl=yes "
    end

    str << " include_flags=\"#{@options[:include_paths]}\"" if @options[:include_paths].length > 0
    str << " library_flags=\"#{@options[:library_paths]}\"" if @options[:library_paths].length > 0
    str
  end

  def setup_admin_panel
    print "Setting up server admin panel application database ..."
    Dir.chdir(ADMIN_PANEL_DIR)
    unless @import
      # delete existing database if any
      system("rake db:drop >>#{WEBROAR_ROOT}/install.log 2>>#{WEBROAR_ROOT}/install.log")
      system("rake db:create >>#{WEBROAR_ROOT}/install.log 2>>#{WEBROAR_ROOT}/install.log")
      unless ($? == 0)
        puts " failed."
        puts "Error while creating sqlite database. Please refer 'install.log' for details."
        puts "Unfortunately you would have to setup database manually for the admin panel rails application. Please run *rake db:create* and *rake db:migrate*  from #{ADMIN_PANEL_DIR}"
        install_msg(true)
        return false
      end
    end

    system("rake db:migrate >>#{WEBROAR_ROOT}/install.log 2>>#{WEBROAR_ROOT}/install.log")
    unless ($? == 0)
      puts " failed."
      puts "Error while migrating sqlite database. Please refer 'install.log' for details"
      puts "Unfortunately you would need to migrate database manually for the admin panel rails application. Please run *rake db:migrate*  from #{ADMIN_PANEL_DIR}"
      install_msg(true)
      return false
    end

    puts " done."
    return true
  end

  def install_server
    puts "Installing server ..."
    system("rake create_install_dirs  >>install.log 2>>install.log")
    unless ($?==0)
      puts "Installation error. Please refer 'install.log' for details."
      return false
    end

    return false unless setup_admin_panel
    # Creating soft link for WebROaR and starling process. In most debian system, secure
    # sudo path fails to locate it.
    create_softlink('starling')
    create_softlink('webroar')
    create_softlink('webroar-analyzer')

    tmp_msg = log_rotate unless @import
    @err_msg = @err_msg ? @err_msg + tmp_msg : tmp_msg if tmp_msg

    puts"WebROaR installed successfully."
    return true
  end

  def compile_code(str)
    print "Compiling C source files ..."
    system("rake clobber >>install.log 2>>install.log")
    @options[:debug_build] ? system("rake debug_build #{str} >>install.log 2>>install.log") : system("rake #{str} >>install.log 2>>install.log")
    unless $? == 0
      puts " failed."
      puts "Compilation error. Please refer 'install.log' for details."
      return false
    end

    puts " done."
    return true
  end

  def create_dirs
    print 'Creating directory structure ...'
    Dir.chdir(WEBROAR_ROOT)
    system("ln -s  #{ADMIN_PANEL_DIR} #{WEBROAR_ROOT}>install.log 2>>install.log")
    system("chmod ugo+x #{File.join(WEBROAR_BIN_DIR,'webroar-analyzer')}")
    puts " done."
  end

  def install_msg(flag)
    puts
    puts "Please start the server using the command 'sudo webroar start'" if flag
    puts "Deploy a ruby web application using server admin panel, accessible through the link - http://localhost:#{@port}/admin-panel"
    puts
  end

  # Create a soft link to file in '/usr/bin' directory
  def create_softlink(file)
    file_name = File.join(USR_BIN_DIR, file)
    system("ln -s #{File.join(GEM_BIN_DIR,file)}  #{USR_BIN_DIR} >>#{File.join(WEBROAR_ROOT,'install.log')} 2>>#{File.join(WEBROAR_ROOT,'install.log')}") if File.exists?(File.join(GEM_BIN_DIR, file)) and !File.exists?(file_name)
  end

  # Remove the link
  def remove_softlink(file)
    file_name = File.join(USR_BIN_DIR, file)
    system("rm #{file_name} >>#{File.join(WEBROAR_ROOT,'uninstall.log')} 2>>#{File.join(WEBROAR_ROOT,'uninstall.log')}") if File.symlink?(file_name)
  end

end #class Installer
