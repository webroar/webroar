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

module Webroar
  module Analyzer
    # ScriptRunner class design inspired from Starling runner
    class ScriptRunner
      def self.run
        new
      end

      private

      # Reading configuration file. Opening log file and PID file on given path.
      def initialize
        @@instance = self
        @configuration = YAML.load(File.open(File.join(WEBROAR_ROOT,'conf','server_internal_config.yml')))
        @process = ProcessHelper.new(@configuration["webroar_analyzer_script"]["log_file"], @configuration["webroar_analyzer_script"]["pid_file"])
        WLogger.set_log_file(@configuration["webroar_analyzer_script"]["log_file"])

        pid = @process.running?
        if pid
          STDERR.puts "There is already a webroar_analyzer process running (pid #{pid}), exiting."
          exit(1)
        elsif pid.nil?
          STDERR.puts "Cleaning up stale pidfile at #{@configuration[:pid_file]}."
        end
        start
      end

      def get_starling_pid
        # read starling process id
        pid_file = YAML.load(File.open(File.join(WEBROAR_ROOT, 'conf', 'starling_server_config.yml')))["starling"]["pid_file"]
        pid = File.read(pid_file).chomp.to_i rescue nil
      end

      def start
        #drop_privileges

        @process.daemonize if @configuration["webroar_analyzer_script"]["daemonize"]

        setup_signal_traps
        @process.write_pid_file

        WLogger.info "Starting webroar-analyzer."
        DBConnect.db_up(@configuration["webroar_analyzer_script"]["environment"])
        @analyzer = ResourceAnalyzer.new(get_starling_pid)
        @processor = MessageAnalyzer.new(MessageReader.new(@configuration["starling"]), @analyzer, @configuration["webroar_analyzer_script"]["sampling_rate"])

        @message_processor = Thread.new {
          while true
            @processor.process_messages
            sleep(60)
          end
        }

        @stale_sample_writer = Thread.new {
          while true
            @processor.process_stale_samples
            sleep(60)
          end
        }

        @resource_monitor = Thread.new {
          while true
            @processor.process_pid
            @analyzer.take_sample
            sleep(60)
          end
        }

        @exception_processor = Thread.new {
          while true
            @processor.process_exceptions
            sleep(60)
          end
        }

        @message_processor.join
        @stale_sample_writer.join
        @resource_monitor.join
        @exception_processor.join

      end

      def shutdown
        begin
          WLogger.info "Got shutdown signal. Processing remaining messages in queue..."
          Thread.kill(@message_processor)
          Thread.kill(@stale_sample_writer)
          Thread.kill(@resource_monitor)
          Thread.kill(@exception_processor)

          @processor.write_all_samples

          WLogger.info "Messages processed."
          WLogger.info "Stopping Starling server...."
          pid = get_starling_pid
          if pid
            system("kill -INT #{pid} 2>/dev/null")
            if $? == 0
              WLogger.info "Stopped."
            else
              WLogger.info "Failed."
            end
          else
            WLogger.info 'Failed to retrieve pid.'
          end
          @process.remove_pid_file
          #TODO: Write data purger
          WLogger.info "Webroar-analyzer process stopped."
        rescue Object => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          WLogger.error "There was an error shutting down: #{e}"
          exit(70)
        end
        exit(0)
      end

      def setup_signal_traps
        Signal.trap("INT") { shutdown }
        Signal.trap("TERM") { shutdown }
        Signal.trap("USR1") {
          @processor.reload_apps
          @analyzer.reload_apps
        }

      end
    end #Runner
  end # Analyzer
end # Webroar
