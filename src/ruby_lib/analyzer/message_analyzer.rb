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

require File.expand_path(File.join(WEBROAR_ROOT,'src','admin_panel', 'config', 'initializers', 'application_constants'))

module Webroar
  module Analyzer
    class MessageAnalyzer
      include WithExceptionHandling

      attr_reader :sampling_rate
      attr_accessor :application_samples, :url_samples
      def initialize(reader, analyzer, sampling_rate = 1)
        @message_reader = reader
        @resources_analyzer = analyzer
        # Keeping application name and its id in memory. Useful in creating sample for the application without querying database.
        @apps = Hash.new
        @sampling_rate = sampling_rate * 60 # rate in seconds
        # @applicatoin_sample is a hash having app_id as key and sample for respective application as value.
        # Sample is an Array having two items.
        # First item is wall_time to determine sampling period in conjuction with sampling_rate.
        # Second item is again an array having summarized value for the sampling period. Array contains total_spent_time, db_time, rendering_time and no_of_requests
        @application_samples = Hash.new
        # @url_sample is hash having app_id as key and hash of url sample for that application as value.
        # Hash of url sample has url as key and sample for that url as value.
        # Sample is an Array having two items.
        # First item is wall_time to determine sampling period in conjuction with sampling_rate.
        # Second item is again an array having summarized value for the sampling period. Array contains total_spent_time, db_time, rendering_time, no_of_requests and hash of db breakup time for a particular url.
        @url_samples = Hash.new
        load_apps
      end

      # Reload instance variables
      def reload_apps
        apps = nil
        with_exception_handling("App entry App.find") do
          apps = App.find(:all,:select => "id, name")
        end

        new_apps = Hash.new
        new_application_samples = Hash.new
        new_url_samples = Hash.new

        apps.each do |app|
          new_apps[app.name] = app.id
          new_application_samples[app.id] = @application_samples[app.id] || Array.new
          new_url_samples[app.id] = @url_samples[app.id] || Hash.new
        end

        @apps = new_apps
        @application_samples = new_application_samples
        @url_samples = new_url_samples

      end # reload_apps

      # This method keep on executing until message queue become empty.
      def process_messages
        begin
          # return on getting nil from @message_reader.read()
          item = @message_reader.read_profiling_data()
          #p item
          while item
            wall_time = item[:wall_time]
            message_type = item[:message_type]
            if message_type == "url_metric"
              # determining different component of measurement and giving it to AppTimeSample and UrlTimeSample.
              reload_apps unless app_id = @apps[item[:app_name]]
              unless app_id = @apps[item[:app_name]]
                WLogger.error("Application #{item[:app_name]} is not found.")
                return
              end
              url = item[:controller_action].shift
              url = url << "/" << item[:controller_action].shift
              total_spent_time =  item[:controller_action].shift
              rendering_time =  item[:rendering]
              db_time = 0
              db_time_breakup = Hash.new
              item[:database].each do |key1, value1|
                value1.each do |key2, value2|
                  db_time = db_time + value2
                  mn = "#{key2}.#{key1}"
                  db_time_breakup[mn] = value2
                end
              end
              #puts "app_id=#{app_id},total_spent_time=#{total_spent_time},wall_time=#{wall_time}"
              begin
                AppTimeSample.add_to_sample(self, app_id, total_spent_time, db_time, rendering_time, wall_time)
                UrlTimeSample.add_to_sample(self, app_id, url, total_spent_time, db_time, rendering_time, db_time_breakup, wall_time)
              rescue Exception => e
                WLogger.error(e)
                WLogger.error(e.backtrace.join("\n"))
              end
            end  # if end
            item = @message_reader.read_profiling_data()
          end # while item
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
          return
        end
      end #process messages

      # @application_samples and @url_samples contains at the most one sample and that is for current sampling period.
      # This method selects and writes all the samples for which sampling period has been passed.
      # Usually this method gets called at interval of 60 seconds.
      def process_stale_samples
        begin
          AppTimeSample.write_stale_samples(self)
          UrlTimeSample.write_stale_samples(self)
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
        end
      end # process_stale_samples

      def process_pid
        item = @message_reader.read_pid()
        while item
          item = item.split(/:/)
          # Registering pid for application. Useful in monitoring the resources used by that application.
          # Usually called when new worker is created.
          @resources_analyzer.set_pid(item[1].to_i, item[0])
          item = @message_reader.read_pid()
        end # while item
      end

      # This method writes all @application_samples and @url_samples into database.
      # Usually called at time of shutdown.
      def write_all_samples
        begin
          AppTimeSample.write_all_samples(self)
          UrlTimeSample.write_all_samples(self)
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
        end
      end

      def process_exceptions
        begin
          exception_hash = @message_reader.read_exception()
          process_exception_hash(exception_hash)
        rescue Exception => e
          WLogger.error(e)
          WLogger.error(e.backtrace.join("\n"))
        end
      end

      def process_exception_hash(exception_hash)
        while exception_hash
          if exception_hash[:app_name]
            app = App.get_application_data(exception_hash[:app_name])
            unless app
              exception_hash = @message_reader.read_exception()
              next
            end
            exception = AppException.get_exception_for_analyzer(exception_hash,app.id)
            status = OPEN_EXCEPTION
            if exception
              change_status_to_open(exception) if exception.exception_status.to_i == CLOSED_EXCEPTION # if its been closed, mark entry as open
            else
              # New exception,  set it as PERMANENTLY_IGNORED_EXCEPTION if exception class falls into
              # PERMANENTLY_IGNORED_LIST otherwise set it as Open
              status = PERMANENTLY_IGNORED_EXCEPTION if(permanently_ignored?(exception_hash[:app_name],exception_hash[:exception_class]))
              exception = save_exception(app.id,exception_hash,status)
            end
            save_exception_details(exception,exception_hash)
            if status == OPEN_EXCEPTION
              Mailer.send_exception(exception_hash)
            end
          end
          exception_hash = @message_reader.read_exception()
        end
      end

      def change_status_to_open(exception)
        with_exception_handling("Exception entry - Update existing entry status to OPEN") do
          exception.exception_status = OPEN_EXCEPTION
          exception.save!
        end
      end

      def save_exception(app_id,exception_hash,status)
        with_exception_handling("Exception entry AppException.create") do
          exception = AppException.create({:app_id => app_id,  :exception_message => exception_hash[:exception_message],
            :exception_class => exception_hash[:exception_class],:exception_status => status,
            :controller => exception_hash[:controller],:method => exception_hash[:method]})
        end
      end

      def get_exception_details_hash(exception_hash)
        exception_details_hash = Hash.new
        ExceptionDetail.columns.each { |column|  exception_details_hash[column.name] = nil }
        exception_details_hash.delete("id")
        exception_details_hash.each_key do |key|
          exception_details_hash[key] = exception_hash[key.to_sym]
        end
        exception_details_hash
      end

      def save_exception_details(exception,exception_hash)
        exception_details_hash = get_exception_details_hash(exception_hash)
        with_exception_handling("ExceptionDetails entry exception.exception_details.create") do
          exception.exception_details.create(exception_details_hash)
        end
      end

      private

      def load_apps
        apps = nil
        with_exception_handling("App entry App.find") do
          apps = App.find(:all,:select => "id, name")
        end

        apps.each do |app|
          @apps[app.name] = app.id
          @application_samples[app.id] = Array.new
          @url_samples[app.id] = Hash.new
        end
      end

      # This method is used to check the class of incomming exceptions
      # whether class is included in permanently ignored list or not.
      def permanently_ignored?(app_name, class_type)
        info = YAML::load_file("#{WEBROAR_ROOT}/conf/config.yml") rescue nil
        app_data = info['Application Specification'].detect{|app_item| app_item["name"].eql?(app_name)}
        if app_data["permanently_ignored_list"]
          app_data["permanently_ignored_list"].include?(class_type)
        end
      end

    end #class MessageAnalyzer
  end #module Analyzer
end #module Webroar
