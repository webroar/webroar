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
#$LOAD_PATH.unshift("#{File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'activerecord', 'lib')}")
#$LOAD_PATH.unshift("#{File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'activesupport', 'lib')}")
#require File.join(ADMIN_PANEL_ROOT,'vendor', 'rails', 'activerecord', 'lib', 'active_record')
gem 'activesupport', '=2.3.2'
gem 'activerecord', '=2.3.2'
require 'activerecord'

module Webroar
  module Analyzer
    module DBConnect
      def self.get_db_configuration(environment='production')
        config = YAML.load_file(File.join(ADMIN_PANEL_ROOT, 'config', 'database.yml'))
        configuration = config[environment]
        if configuration["adapter"] == "sqlite3" and !configuration['database'].start_with?('/')
          db_file = File.expand_path(File.join(ADMIN_PANEL_ROOT, configuration["database"]))
          configuration["database"] = db_file
        end
        configuration
      end
      
      def self.load_models      
        models = Dir.glob(File.join(ADMIN_PANEL_ROOT, 'app', 'models', '**', '*.rb'))
        unloaded = Array.new
        models.each do |f|
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
      
      def self.establish_connection(environment='production')
        begin
          ActiveRecord::Base.establish_connection(get_db_configuration(environment))
        rescue Exception => e        
          Logger.error(e)
          Logger.error(e.backtrace.join("\n"))
        end
      end
      
    end # DBConnect
  end
end
