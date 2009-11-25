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

require File.expand_path(File.join(File.dirname(__FILE__), 'process_helper.rb'))

module Webroar
  module Analyzer
    # ScriptRunner class design inspired from Starling runner
    class ScriptRunner
      def self.run       
        new        
      end # self.run
      
      def self.stop
        @@instance.shutdown
      end
      
      # Reading configuration file. Opening log file and PID file on given path.
      def initialize
        @@instance = self
        filename = File.expand_path(File.join(WEBROAR_ROOT,'conf','server_internal_config.yml'))
        @configuration = load_config_file(filename)
        @process = ProcessHelper.new(@configuration["webroar_analyzer_script"]["log_file"], @configuration["webroar_analyzer_script"]["pid_file"])
        Logger.set_log_file(@configuration["webroar_analyzer_script"]["log_file"])
        
        pid = @process.running?
        if pid
          STDERR.puts "There is already a webroar_analyzer process running (pid #{pid}), exiting."
          exit(1)
        elsif pid.nil?
          STDERR.puts "Cleaning up stale pidfile at #{@configuration[:pid_file]}."
        end
        start
      end
      
      def load_config_file(filename)
        YAML.load(File.open(filename))
      end
      
      def get_starling_pid
        # read starling process id        
        filename = File.join(WEBROAR_ROOT, 'conf', 'starling_server_config.yml')
        pid_file = YAML.load(File.open(filename))["starling"]["pid_file"]
        pid = File.read(pid_file).chomp.to_i rescue nil
      end
      
      def start
        #drop_privileges
        
        @process.daemonize if @configuration["webroar_analyzer_script"]["daemonize"]
        
        setup_signal_traps
        @process.write_pid_file
        
        Logger.info "Starting webroar-analyzer."
        DBConnect.establish_connection(@configuration["webroar_analyzer_script"]["environment"])
        DBConnect.load_models
        @reader = MessageReader.new(@configuration["starling"]["host"], @configuration["starling"]["port"], @configuration["starling"]["profiler_queue_name"], @configuration["starling"]["exception_queue_name"], @configuration["starling"]["pid_queue_name"])
        starling_pid = get_starling_pid
        @analyzer = ResourceAnalyzer.new(starling_pid)
        @processor = MessageAnalyzer.new(@reader, @analyzer, @configuration["webroar_analyzer_script"]["sampling_rate"])
      
        mutex = Mutex.new
        @message_processor = Thread.new {
          while true
            #            mutex.synchronize do
            @processor.process_messages
            #            end
            sleep(60)
          end
        }
        @stale_sample_writer = Thread.new {
          while true
            #            mutex.synchronize do
            @processor.process_stale_samples
            #            end
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
            #            mutex.synchronize do
            @processor.process_exceptions
            #            end
            sleep(60)
          end
        }
        
#        @pid_processor = Thread.new {
#          while true
#            @processor.process_pid
#            sleep(30)
#          end
#        }
        @message_processor.join
        @stale_sample_writer.join
        @resource_monitor.join
        @exception_processor.join
#        @pid_processor.join
      end
      
      #def drop_privileges
      #	Process.egid = options[:group] if options[:group]
      #	Process.euid = options[:user] if options[:user]
      #end
      
      def shutdown
        begin
          Logger.info "Got shutdown signal. Processing remaining messages in queue..."
          Thread.kill(@message_processor)
          Thread.kill(@stale_sample_writer)
          Thread.kill(@resource_monitor)
          Thread.kill(@exception_processor)
#          Thread.kill(@pid_processor)
          #@processor.process_messages
          @processor.write_all_samples
          #@processor.process_exceptions
          Logger.info "Messages processed."
          Logger.info "Stopping Starling server...."
          pid = get_starling_pid
          if pid
            system("kill -INT #{pid} 2>/dev/null")
            if $? == 0
              Logger.info "Stopped."
            else
              Logger.info "Failed."
            end
          else
            Logger.info 'Failed to retrieve pid.'
          end
          @process.remove_pid_file
          #TODO: Write data purger
          Logger.info "Webroar-analyzer process stopped."
        rescue Object => e
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
          Logger.error "There was an error shutting down: #{e}"
          exit(70)
        end
        exit(0)
      end
      
      def setup_signal_traps
        Signal.trap("INT") { shutdown }
        Signal.trap("TERM") { shutdown }
      end
    end #Runner
  end # Analyzer
end # Webroar
