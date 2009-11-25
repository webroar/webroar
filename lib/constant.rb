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

WEBROAR_TEST_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'test', 'unit'))
#WEBROAR_RUBY_LIB_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'src', 'ruby_lib'))
WEBROAR_BIN_DIR = File.expand_path(File.join(WEBROAR_ROOT, 'bin'))
ADMIN_PANEL_DIR = File.join(WEBROAR_ROOT, 'src', 'admin_panel')
ADMIN_PANEL_LIB_DIR = File.join(ADMIN_PANEL_DIR, 'lib')
RAILS_ROOT=ADMIN_PANEL_DIR
GEM_BIN_DIR = File.expand_path(File.join(WEBROAR_ROOT,'..','..','bin'))
USR_BIN_DIR = File.join('','usr','bin')

ENV["PATH"] += ":/usr/bin:/usr/sbin:/sbin:/usr/local/sbin:#{WEBROAR_BIN_DIR}"
WEBROAR_LOG_FILE = File.join('','var','log','webroar','webroar.log')
PIDFILE = "/var/run/webroar.pid"
TESTFILE = "/etc/profile"
MESSAGE_DEPLOYMENT = "This command needs to be run as root. Please try again using 'sudo'.".freeze

#$LOAD_PATH.unshift("#{WEBROAR_RUBY_LIB_DIR}")
$LOAD_PATH.unshift("#{ADMIN_PANEL_LIB_DIR}")

class CheckUser

  # Check for root user
  def check
    if File.writable?(TESTFILE)
      return 0
    else
      puts "#{MESSAGE_DEPLOYMENT}"
      return -1
    end
  end

end #class CheckUser
