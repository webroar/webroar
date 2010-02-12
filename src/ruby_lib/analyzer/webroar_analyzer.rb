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

require File.expand_path(File.join(File.dirname(__FILE__), 'user_defined_exception.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'with_exception_handling'))
require File.expand_path(File.join(File.dirname(__FILE__), 'db_connect.rb'))
require File.expand_path(File.join(File.dirname(__FILE__) , 'message_reader.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'message_analyzer.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'resources_analyzer.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'webroar_analyzer_script_runner.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'logger.rb'))


Webroar::Analyzer::ScriptRunner.run

