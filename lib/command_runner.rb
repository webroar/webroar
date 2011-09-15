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

module Webroar
  module Command
    HELP =%{
  Usage:
    webroar [-v | --version] [-h | --help] COMMAND [ARGS]

  The available webroar commands are:
    install       Install the server
    uninstall     Uninstall the server
    start         Start the server or an application
    stop          Stop the server or an application
    restart       Restart the server or an application
    add           Deploy an application on the server
    remove        Remove an application from the server
    test          Run the test suite

  For help on a particular command, use 'webroar help COMMAND'.
}

    HELP_INSTALL =%{
  Usage:
    webroar install [-s] [ -L<library path>] [ -I<include path>] [-d] [ -i |
                    [ --no-import] [ -P<port>] [ -u<user>] [-p<password>] ]

  Options:
    -L
        Additional library paths to be used for linking of the server

    -I
        Additional include paths to be used for linking of the server

    -s, --ssl-support
        Install the server with SSL support

    -d, --debug-build
        Compile the server as a debug build to output extremely verbose logs

  The following options would make the install non-interactive by suppressing 
  the questions prompted by the installer

    -P, --port
        Server port number

    -i, --import
        Import configuration, logs and admin panel data from the previous 
	installation

    --no-import
        Do not import configuration, logs and admin panel data from the previous 
	installation

    -u, --username
        Username for the administrator account of server's admin panel

    -p, --password
        Password for the administrator account of server\'s admin panel

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
    webroar start [<app(s)>]

  Arguments:
    <app(s)>
        Name of the application(s)

  Summary:
    Start the server or an application

  Description:
    'start' command without any arguments starts the server. One can start
    multiple applications together by passing multiple names.
  }

    HELP_STOP =%{
  Usage:
    webroar stop [<app(s)>]

  Arguments:
    <app(s)>
        Name of the application(s)

  Summary:
    Stop the server or an application

  Description:
    'stop' command without any arguments stops the server. One can stop
    multiple applications together by passing multiple names.
  }

    HELP_RESTART =%{
  Usage:
    webroar restart [<app(s)>]

  Arguments:
    <app(s)>
        Name of the application(s)

  Summary:
    Restart the server or an application

  Description:
    'restart' command without any arguments restarts the server. One can
    restart multiple applications together by passing multiple names.
  }

    HELP_TEST =%{
  Usage:
    webroar test [ -r<report dir>] [ -d] [ -l]

  Options:
    -r, --report-dir
        Report directory

    -d, --debug-build
        Compile the server as a debug build to output extremely verbose logs

    -l, --load-test
        Also run the load tests

  Summary:
    Run the test suite
  }

    HELP_REMOVE = %{
  Usage:
    webroar remove [<app>]

  Arguments:
    <app>
        Name of the application

  Summary:
    Remove the specified application from the server.

  Description:
    If application name is not passed, it would look for 'config/environment.rb'
    or 'config.ru' file in the current directory. If any one of the files found,
    it passes name of the current directory as an application name.
    
}

    HELP_ADD = %{
  Usage:
    webroar add [<app>] [ -R] [ -D] [ -U] [ -T] [ -E] [ -A] [ -N] [ -X]

  Arguments:
    <app>
        Name of the application

  Options:
    The following parameters are mandatory, if the current directory would not
    be the Rails or Rack root directory

    -R, --resolver
        Resolver to identify the application. Set it to '/' if you would like
        to run the application on the root domain. e.g. http://yourserver:port/.
        (default: /<app>)

        Else set the relevant base URI with which you would like to access the
        application, e.g. '/app1' if you want the application to be accessible
        via http://yourserver:port/app1.

        If you would like to set a virtual host for your application e.g.
        www.company1.com, please specify it here. You can also host this
        application on a particular subdomain e.g. app1.company1.com. Wildcard
        '*' can also be used in defining the virtual host name, but it should
        only be used either at the start or the end. Prefix the virtual host
        name with tilde(~), if a wildcard is used in defining it.
        e.g. (i) ~*.server.com (ii) ~www.server.* (iii) ~*.server.*

    -D, --path
        Complete path for your application root directory: e.g. /home/someuser/webapps/app1
        (default: current directory)

    -U, --run-as-user
        Name of the user with whose privileges you would like to run the
        application (root can be dangerous!). This user should have all the
        necessary permissions to get your web application working properly
        (e.g. write access on required files and directories etc)
        (default: Owner of 'config/environment.rb' or 'config.ru' file)

    The following parameters are optional

    -T, --type
        Type of the application either rack or rails (default: rails)

    -E, --environment
        Environment in which you want to run the application (default: production)

    -A, --analytics
        Enable analytics to get detailed numbers about the run time performance
        of the application. This number gathering adds a very small overhead on
        your application

    -N, --min-workers
        Minimum number of worker processes that should run for this deployed
        application. Multiple worker instances help in processing a higher number 
        of concurrent user requests simultaneously. The server would always
        ensure at least these many worker processes run for this application
       (default: 4)

    -X, --max-workers
        Maximum number of worker processes that should run for this deployed
        application. Multiple worker instances help in processing a higher
        number of concurrent user requests simultaneously. The server would
        ensure that maximum only these many worker processes run for this
        application (default: 8)

  Summary:
    Deploy (and start) a new application on the server.

  Description:
    If application name is not passed, it would look for 'config/environment.rb'
    or 'config.ru' file in the current directory. If any one of the files found,
    it passes name of the current directory as an application name.
    
}
    class CommandRunner
      def initialize
        @options = {}
        @options[:include_paths] = ""
        @options[:library_paths] = ""
      end

      def run

        return unless parse_args

        if ARGV.length == 0
          if @options[:version]
            Installer.new.version
          else
            puts HELP
          end
          return
        end

        cmd = ARGV[0]

        if @options[:help]
          Help.new.run(cmd)
          return
        end

        case cmd
        when "help"; Help.new.run(ARGV[1])
        when "install";
          # When installation is interrupted on administrator account password input, terminal
          # is set to echo the character
          begin
            Installer.new.install(@options)
          ensure
            system('stty echo')
          end
        when "uninstall"; Installer.new.uninstall
        when "clear"; WebroarCommand.new.clear
        when "start", "stop", "restart" ; WebroarCommand.new.operation(ARGV, cmd)
        when "add" ; WebroarCommand.new.add(@options, ARGV)
        when "remove" ; WebroarCommand.new.remove(ARGV)
        when "test"; Installer.new.test(@options)
        else
          puts "ERROR:  Invalid command: #{cmd}.  See 'webroar help'."
        end
      end

      private

      def parse_args

        optparse = OptionParser.new do|opts|

          opts.on( '-h', '--help', 'Webroar help') { @options[:help] = true }
          opts.on( '-s', '--ssl-support', 'Install with SSL support') { @options[:ssl] = true }
          opts.on( '-d', '--debug-build', 'Compile with debug mode') { @options[:debug_build] = true }
          opts.on( '-n', '--no-report', 'Do not generate test report') { @options[:no_report] = true }
          opts.on( '-l', '--load-test', 'Run load test') { @options[:load_test] = true }
          opts.on( '-A', '--analytics', 'Enable the application analytics') { @options[:analytics] = 'Enabled' }
          opts.on( '-i', '--import', 'Import configuration, logs and admin panel data from the previous installation') { @options[:import] = true }
          opts.on( '--no-import', 'Do not import configuration, logs and admin panel data from the previous installation') { @options[:import] = false }

          opts.on( '-v', '--version', 'Version information') do
            @options[:version] = true
            #Installer.new.version
            #return false
          end

          opts.on( '-u', '--username USERNAME', 'Username for the administrator account of server\'s admin panel') do |value|
            @options[:username] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-p', '--password PASSWORD', 'Password for the administrator account of server\'s admin panel') do |value|
            @options[:password] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-P', '--port PORT', 'Server port number') do |value|
            @options[:port] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-r', '--report-dir [DIR]', 'Report directory') do |value|
            @options[:report_dir] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-R', '--resolver RESOLVER', 'Resolver to identify the application') do |value|
            @options[:resolver] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-D', '--path DIR', 'Path for the web application root directory') do |value|
            @options[:path] = value.lstrip.gsub(/^=/,"")
            @options[:path] = File.expand_path(@options[:path])
          end

          opts.on( '-T', '--type APPTYPE', 'Type of the application either rack or rails') do |value|
            @options[:type1] = value.lstrip.gsub(/^=/,"").capitalize
          end

          opts.on( '-E', '--environment ENV', 'Environment in which you want to run the application') do |value|
            @options[:environment] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-N', '--min-workers WORKER', 'Minimum number of worker processes that should run for the deployed application.') do |value|
            @options[:min_worker] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-X', '--max-workers WORKER', 'Maximum number of worker processes that should run for the deployed application.') do |value|
            @options[:max_worker] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-U', '--run-as-user USERNAME', 'Name of the user with whose privileges you would like to run the application') do |value|
            @options[:run_as_user] = value.lstrip.gsub(/^=/,"")
          end

          opts.on( '-L PATH', 'Additional library path') do |value|
            @options[:library_paths] += " -L'#{value.lstrip.gsub(/^=/,"")}'"
          end

          opts.on( '-I PATH', 'Additional include path') do |value|
            @options[:include_paths] += " -I'#{value.lstrip.gsub(/^=/,"")}'"
          end

        end

        begin
          optparse.parse!
        rescue OptionParser::ParseError => err
          puts "#{err}. See 'webroar help'."
          return false
        end

        return true

      end

    end   # class CommandRunner

    class Help
      def run (cmd)
        case cmd
        when nil, "help"; puts HELP
        when "install"; puts HELP_INSTALL
        when "uninstall"; puts HELP_UNINSTALL
        when "clear"; puts HELP_CLEAR
        when "start"; puts HELP_START
        when "stop"; puts HELP_STOP
        when "restart"; puts HELP_RESTART
        when "add"; puts HELP_ADD
        when "remove"; puts HELP_REMOVE
        when "test"; puts HELP_TEST
        else puts "WARNING:  Unknown command #{cmd}. See 'webroar help'."
        end
      end

    end  # class Help
  end # module Command
end # module Webroar
