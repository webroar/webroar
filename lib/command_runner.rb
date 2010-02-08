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

require 'optparse'

HELP =%{
  WebROaR is a ruby application server. This is a basic help message.

    Usage:
      webroar -h/--help
      webroar -v/--version
      webroar command [argument] [options...]

    Examples:
      webroar install
      webroar help

    Further help:
      webroar help commands      list all 'webroar' commands
      webroar help <COMMAND>     show help on COMMAND
}

HELP_COMMAND =%{
  WebROaR commands are:

    install            Install the server
    uninstall          Uninstall the server
    start [APPNAME]    Start the server or an application
    stop [APPNAME]     Stop the server or an application
    restart [APPNAME]  Restart the server or an application
    test               Run the test suite

  For help on a particular command, use 'webroar help COMMAND'.
  }

HELP_INSTALL =%{

  Usage:
    webroar install [options]

  Options:
    -d, --debug-build      Compile the server as a debug build to output extremely verbose logs 
    -i, --[no-]import      Import configuration, logs and admin panel data from the previous installation
    -p, --password         Password for the administrator account of server\'s admin panel
    -P, --port             Server port number
    -s, --ssl-support      Install the server with SSL support
    -u, --username         Username for the administrator account of server's admin panel
    -L                     Additional library path
    -I                     Additional include path

  Summary:
    Install the server
  }

HELP_UNINSTALL =%{
  Usage:
    webroar uninstall

  Summary:
    Uninstall the server
  }

HELP_CLEAR =%{
  Usage:
    webroar clear

  Summary:
    Clear the log files

  Description:
    Clear the log files from '/var/log/webroar' directory.
  }

HELP_START =%{
  Usage:
    webroar start [APPNAME ...] 

  Arguments:
    APPNAME        Name of the application to start 

  Summary:
    Start the server or an application 

  Description:
    'start' command without any arguments starts the server. One can start
    multiple applications together by passing multiple names.
  }

HELP_STOP =%{
  Usage:
    webroar stop [APPNAME ...] 

  Arguments:
    APPNAME        Name of the application to stop 

  Summary:
    Stop the server or an application 

  Description:
    'stop' command without any arguments stops the server. One can stop multiple
    applications together by passing multiple names.
  }

HELP_RESTART =%{
  Usage:
    webroar restart [APPNAME ...] 

  Arguments:
    APPNAME        Name of the application to restart 

  Summary:
    Restart the server or an application 

  Description:
    'restart' command without any arguments restarts the server. One can restart
    multiple applications together by passing multiple names.
  }

HELP_TEST =%{
  Usage:
    webroar test [options] 

  Options:
    -d, --debug-build       Compile the server as a debug build to output extremely verbose logs
    -l, --load-test         Also run the load tests
    -r, --report-dir DIR    Report directory 

  Summary:
    Run the test suite
  }

HELP_REMOVE = %{
  Usage:
    webroar remove APPNAME

  Arguments:
    APPNAME        Name of the application to remove

  Summary:
    Remove the applicaiton from the server.
}

HELP_ADD = %{
  Usage:
    webroar add APPNAME [options]

  Options:
    -R, --resolver
          Resolver to identify the application. Set it to '/' if you would like to run the application on the root domain. e.g. http://yourserver:port/.
          Else set the relevant base URI with which you would like to access the application, e.g. '/app1' if you want the application to be accessible via http://yourserver:port/app1.
          If you would like to set a virtual host for your application e.g. www.company1.com, please specify it here. You can also host this application on a particular subdomain e.g. app1.company1.com. Wildcard '*' can also be used in defining the virtual host name, but it should only be used either at the start or the end. Prefix the virtual host name with tilde(~), if a wildcard is used in defining it. e.g. (i) ~*.server.com (ii) ~www.server.* (iii) ~*.server.*
    -D, --path
          Path for the web application root directory.
    -t, --type
          Type of the application either rack or rails.
    -e, --environment
          Environment in which you want to run the application.
    -a, --[no-]analytics
          Enable analytics to get detailed numbers about the run time performance of the application. his number gathering adds a very small overhead on your application.
    -N, --min-workers
          Minimum number of worker processes that should run for the deployed application.
    -x, --max-workers
          Maximum number of worker processes that should run for the deployed application.
    -U, --run-as-user
          Name of the user with whose privileges you would like to run the application. This user should have all the necessary permissions to get your web application working properly.

  Summary:
    Add and start an application on the server.
}

class CommandRunner

  def run

    options = {}
    options[:include_paths] = ""
    options[:library_paths] = ""

    optparse = OptionParser.new do|opts|
    
    opts.on( '-h', '--help', 'Version information') { options[:help] = true }
    opts.on( '-s', '--ssl-support', 'Install with SSL support') { options[:ssl] = true }
    opts.on( '-d', '--debug-build', 'Compile with debug mode') { options[:debug_build] = true }
    opts.on( '-n', '--no-report', 'Do not generate test report') { options[:no_report] = true }
    opts.on( '-l', '--load-test', 'Run load test') { options[:load_test] = true }
    opts.on( '-a', '--analytics', 'Enable the application analytics') { options[:analytics] = true }
    opts.on( '--no-analytics', 'Disable the application analytics') { options[:analytics] = false }
    opts.on( '-i', '--import', 'Import configuration, logs and admin panel data from the previous installation') { options[:import] = true }
    opts.on( '--no-import', 'Do not import configuration, logs and admin panel data from the previous installation') { options[:import] = false }
    
    opts.on( '-v', '--version', 'Version information') do
      Installer.new.version
      exit
    end
    
    opts.on( '-u', '--username USERNAME', 'Username for the administrator account of server\'s admin panel') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:username] = value
    end

    opts.on( '-p', '--password PASSWORD', 'Password for the administrator account of server\'s admin panel') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:password] = value
    end

    opts.on( '-P', '--port PORT', 'Server port number') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:port] = value
    end

    opts.on( '-r', '--report-dir [DIR]', 'Report directory') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:report_dir] = value
    end

    opts.on( '-R', '--resolver RESOLVER', 'Resolver to identify the application') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:resolver] = value
    end

    opts.on( '-D', '--path DIR', 'Path for the web application root directory') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:path] = value
    end

    opts.on( '-t', '--type APPTYPE', 'Type of the application either rack or rails') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:type1] = value.capitalize
    end

    opts.on( '-e', '--environment ENV', 'Environment in which you want to run the application') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:environment] = value
    end

    opts.on( '-N', '--min-workers WORKER', 'Minimum number of worker processes that should run for the deployed application.') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:min_worker] = value
    end

    opts.on( '-x', '--max-workers WORKER', 'Maximum number of worker processes that should run for the deployed application.') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:max_worker] = value
    end

    opts.on( '-U', '--run-as-user USERNAME', 'Name of the user with whose privileges you would like to run the application') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:run_as_user] = value
    end
    
    opts.on( '-L PATH', 'Additional library path') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:library_paths] += " -L'#{value}'"
    end
    
    opts.on( '-I PATH', 'Additional include path') do |value|
      value.lstrip!
      value.gsub!(/^=/,"")
      options[:include_paths] += " -I'#{value}'"
    end

  end

  begin
    optparse.parse!
  rescue OptionParser::ParseError => e
    puts "#{e}. See 'webroar --help'."
    exit
  end

  if ARGV.length == 0
    puts HELP
    exit
  end

  if options[:help]
    ARGV[1] = ARGV[0]
    Help.new.run(options, ARGV)
    exit
  end

  case ARGV[0]
    when "help"; Help.new.run(options, ARGV)
    when "install"; 
      # When installation is interrupted on administrator account password input, terminal
      # is set to echo the character 
      begin
        Installer.new.install(options, ARGV)
      rescue Interrupt
      ensure
        system('stty echo')
      end
    when "uninstall"; Installer.new.uninstall(options, ARGV)
    when "clear"; WebroarCommand.new.clear(options, ARGV)
    when "start" ; WebroarCommand.new.start(options, ARGV)
    when "stop" ; WebroarCommand.new.stop(options, ARGV)
    when "restart" ; WebroarCommand.new.restart(options, ARGV)
    when "add" ; WebroarCommand.new.add(options, ARGV)
    when "remove" ; WebroarCommand.new.remove(options, ARGV)
    when "test"; Installer.new.test(options, ARGV)
  else
    puts "ERROR:  Invalid command: #{ARGV[0]}.  See 'webroar help commands'."
  end
end
end   # class Command

class Help

def run (options, args)
  case args[1]
    when nil, "help"; puts HELP
    when "commands"; puts HELP_COMMAND
    when "install"; puts HELP_INSTALL
    when "uninstall"; puts HELP_UNINSTALL
    when "clear"; puts HELP_CLEAR
    when "start"; puts HELP_START
    when "stop"; puts HELP_STOP
    when "restart"; puts HELP_RESTART
    when "add"; puts HELP_ADD
    when "remove"; puts HELP_REMOVE
    when "test"; puts HELP_TEST
  else puts "WARNING:  Unknown command #{args[1]}. See 'webroar help commands'."
  end

end



end  # class help
