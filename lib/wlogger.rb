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
  # Logging messages
    class WLogger
      class << self
        def set_log_file(log_file)
          @@log_file = log_file.freeze
          @@debug_msg = true
        end

        def info(str)
          log_to_file("Info: " + str.to_s)
        end

        def error(str)
          log_to_file("Error: " + str.to_s)
        end

        def debug(str)
          log_to_file("Debug: " + str.to_s) if @@debug_msg
        end

        private

        def log_to_file(str)
          begin
            File.open(@@log_file, "a") do |f|
              f.puts get_identifier + str
            end
          rescue Errno::ENOENT
            puts get_identifier + str
          end
        end

        def get_identifier
          "#{Time.now.strftime('%a %b %d %H:%M:%S %Y')}-#{Process.pid}-"
        end
      end # << self
    end # Class WLogger
  
end # module Webroar
