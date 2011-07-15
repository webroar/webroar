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
  
  module VERSION #:nodoc:
    MAJOR    = "0"
    MINOR    = "6"
    TINY     = "0"

    STRING   = [MAJOR, MINOR, TINY].join('.')
  end
  ruby_version = RUBY_VERSION.split(".")
  RUBY_MAJOR    = ruby_version[0]
  RUBY_MINOR    = ruby_version[1]
  RUBY_TINY     = ruby_version[2]
  NAME    = 'WebROaR'.freeze
  SERVER  = "#{NAME}-#{VERSION::STRING}".freeze
  
end
