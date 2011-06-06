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

require 'rubygems'
gem 'activerecord','2.3.9'
require 'active_record'

module Webroar
  class DBConnect
    class << self
      def db_up(environment='production')

        begin
          ActiveRecord::Base.establish_connection(get_db_configuration(environment))
          load_models
        rescue NameError => e
          puts e
          puts e.backtrace.join("\n")
        end

      end

      private

      def load_models
        models = Dir.glob(File.join(ADMIN_PANEL_DIR, 'app', 'models', "{pseudo_model,application_specification,server_specification,app,url_breakup_time_sample,app_time_sample,resource_usage,url_time_sample,app_exception,exception_detail,mailer}.rb"))

        models.each do |f|
          begin
            require f
          rescue  NameError => e
            puts e
            puts e.backtrace.join("\n")
          end
        end

      end

      def get_db_configuration(environment)
        config = YAML.load_file(File.join(ADMIN_PANEL_DIR, 'config', 'database.yml'))
        configuration = config[environment]

        if configuration["adapter"] == "sqlite3" and !configuration['database'].start_with?('/')
          db_file = File.expand_path(File.join(ADMIN_PANEL_DIR, configuration["database"]))
          configuration["database"] = db_file
        end

        configuration
      end

    end # self
  end # class DBConnect
end  # module Webroar
