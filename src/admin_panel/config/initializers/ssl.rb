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



ADMIN_PANEL_ROOT = File.expand_path('../../../', __FILE__) unless defined?ADMIN_PANEL_ROOT

CONF_FILE  = File.join(ADMIN_PANEL_ROOT,'..','..','conf','config.yml')

server_spec = YAML.load(File.open(CONF_FILE))["Server Specification"]

if(server_spec and 
      server_spec["SSL Specification"] and 
      server_spec["SSL Specification"]["ssl_support"] and
      server_spec["SSL Specification"]["ssl_support"] == "enabled")
  SSL_ON = true
  
  if(server_spec and server_spec["SSL Specification"] and server_spec["SSL Specification"]["ssl_port"])
    SVR_SSL_PORT = server_spec["SSL Specification"]["ssl_port"]
  else
    SVR_SSL_PORT = 0
  end

  if(server_spec and server_spec["port"])
    SVR_PORT = server_spec["port"]
  else
    SVR_PORT = 0
  end
else
  SSL_ON = false
  SVR_SSL_PORT = 0
  SVR_PORT = 0
end


