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
    webroar install [option]

  Options:
    -s, --ssl-support      Install the server with SSL support
    -d, --debug-build      Compile the server as a debug build to output extremely verbose logs 

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
    webroar test [options...] 

  Options:
    -l, --load-test         Also run the load tests
    -d, --debug-build       Compile the server as a debug build to output extremely verbose logs
    -r, --report-dir DIR    Report directory 

  Summary:
    Run the test suite
  }

class CommandRunner

  def run
    options = {}
    optparse = OptionParser.new do|opts|

    opts.on( '-v', '--version', 'Version information') do
      Installer.new.version
      exit
    end

    opts.on( '-h', '--help', 'Version information') do
      options[:help] = true
    end

    opts.on( '-s', '--ssl-support', 'Install with SSL support') do
      options[:ssl] = true
    end

    opts.on( '-d', '--debug-build', 'Compile with debug mode') do
      options[:debug_build] = true
    end

    opts.on( '-l', '--load-test', 'Run load test') do
      options[:load_test] = true
    end

    opts.on( '-n', '--no-report', 'Do not generate test report') do
      options[:no_report] = true
    end

    opts.on( '-r', '--report-dir [DIR]', 'Report directory') do |dir|
      dir.lstrip!
      dir.gsub!("=","")
      options[:report_dir] = dir
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
    when "test"; puts HELP_TEST
  else puts "WARNING:  Unknown command #{args[1]}. See 'webroar help commands'."
  end

end



end  # class help
