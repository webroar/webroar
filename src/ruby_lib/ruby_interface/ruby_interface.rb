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

# Ruby library to be working as interface to C and Rack adapter. 

require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'constants'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'version'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'logger'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'adapter'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'utils'))
#require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'deflater'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'request_handler'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'client'))
require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'ruby_interface', 'request_body'))
