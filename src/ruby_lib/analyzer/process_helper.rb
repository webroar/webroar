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

require 'fileutils'
module Webroar
  module Analyzer
  # ScriptRunner class design inspired from Starling runner
    class ScriptRunner
      class ProcessHelper
        def initialize(log_file = nil, pid_file = nil, user = nil, group = nil)
          @log_file = log_file
          @pid_file = pid_file
          #@user = user
          #@group = group
        end

        def safefork
          begin
            if pid = fork
              return pid
            end
          rescue Errno::EWOULDBLOCK
            sleep 5
            retry
          end
        end

        def daemonize
          sess_id = detach_from_terminal
          exit if pid = safefork

          Dir.chdir("/")
          File.umask 0000

          close_io_handles
          redirect_io

          return sess_id
        end

        def detach_from_terminal
          srand
          safefork and exit

          unless sess_id = Process.setsid
            raise "Couldn't detach from controlling terminal."
          end

          trap 'SIGHUP', 'IGNORE'

          sess_id
        end

        def close_io_handles
          ObjectSpace.each_object(IO) do |io|
            unless [STDIN, STDOUT, STDERR].include?(io)
              begin
                io.close unless io.closed?
              rescue Exception
              end
            end
          end
        end

        def redirect_io
          begin; STDIN.reopen('/dev/null'); rescue Exception; end

          if @log_file
            begin
              STDOUT.reopen(@log_file, "a")
              STDOUT.sync = true
            rescue Exception          
              begin; STDOUT.reopen('/dev/null'); rescue Exception; end
              system("echo Error redirecting STDOUT to '#{@log_file}'. Redirecting to '/dev/null'.")
            end
          else
            begin; STDOUT.reopen('/dev/null'); rescue Exception; end
            system("echo Missing logfile path. You can set it from 'conf/server_internal_config.yml'. Redirecting STDOUT to '/dev/null'.")            
          end

          begin; STDERR.reopen(STDOUT); rescue Exception; end
          STDERR.sync = true
        end

        def rescue_exception
          begin
            yield
          rescue Exception
          end
        end

        def write_pid_file
          return unless @pid_file
          FileUtils.mkdir_p(File.dirname(@pid_file))
          File.open(@pid_file, "w") { |f| f.write(Process.pid) }
          File.chmod(0644, @pid_file)
        end

        def remove_pid_file
          return unless @pid_file
          File.unlink(@pid_file) if File.exists?(@pid_file)
        end

        def running?
          return false unless @pid_file

          pid = File.read(@pid_file).chomp.to_i rescue nil
          pid = nil if pid == 0
          return false unless pid

          begin
            Process.kill(0, pid)
            return pid
          rescue Errno::ESRCH
            return nil
          rescue Errno::EPERM
            return pid
          end
        end

      end # class ProcessHelper
    end # class ScriptRunner
  end # module Analyzer
end # module Webroar

