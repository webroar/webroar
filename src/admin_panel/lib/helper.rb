#--
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
#++
ADMIN_PANEL_ROOT = File.expand_path('../../../', __FILE__) unless defined?ADMIN_PANEL_ROOT

class SignalHelper
  # send signal
  def self.send
    pid_file = nil

    conf_file  = File.join(ADMIN_PANEL_ROOT,'..','..','conf','server_internal_config.yml')

    config = YAML.load_file(conf_file)
    pid_file = config["webroar_analyzer_script"]["pid_file"] if config["webroar_analyzer_script"] and config["webroar_analyzer_script"]["pid_file"]
    unless pid_file
      Rails.logger.error("Either Webroar Analyzer is not started or 'webroar_analyzer.pid' not found")
      return
    end
    pid = File.read(pid_file).chomp.to_i rescue nil
    Process.kill("USR1", pid)
  end
end # class SignalHelper