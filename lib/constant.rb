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

WEBROAR_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
WEBROAR_LIB_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'lib'))
WEBROAR_TEST_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'test', 'unit'))
WEBROAR_BIN_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'bin'))
ADMIN_PANEL_DIR = File.join(WEBROAR_ROOT, 'src', 'admin_panel')
ADMIN_PANEL_LIB_DIR = File.join(ADMIN_PANEL_DIR, 'lib')
RAILS_ROOT = ADMIN_PANEL_DIR
GEM_BIN_DIR = File.expand_path(File.join(WEBROAR_ROOT,'..','..','bin'))
USR_BIN_DIR = File.join('','usr','bin')
ANALYZER_DIR = File.join(WEBROAR_ROOT, 'src', 'ruby_lib', 'analyzer')
INTERNAL_CONF_FILE = File.join(WEBROAR_ROOT, 'conf', 'server_internal_config.yml')
ENV["PATH"] += ":/usr/bin:/usr/sbin:/sbin:/usr/local/sbin:#{WEBROAR_BIN_DIR}"
WEBROAR_LOG_FILE = File.join('','var','log','webroar','webroar.log')
PIDFILE = "/var/run/webroar.pid"
TESTFILE = "/etc/profile"
MESSAGE_DEPLOYMENT = "This command needs to be run as root. Please try again using 'sudo'.".freeze
