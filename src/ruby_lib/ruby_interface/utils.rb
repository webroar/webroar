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
  class Utils
    class << self
      def calculate_content_length(body)
        if body.respond_to?(:to_path)
          #TODO: Some files(e.g. /proc) doesn't provide size info. We may have to figure out
          # by reading entire content.  
          if filesize = File.size?(body.to_path)  
            filesize.to_s
          else
            "0"
          end
        elsif body.kind_of?(String)
          # See http://redmine.ruby-lang.org/issues/show/203
          (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
        else
          # TODO: Yup, this is a ugly hack, accumulating body content at wrong place - only for little performance
          # and DRYing up the things. 
          bytes = 0 
          body_content = []
          body.each do |p|
            bytes += p.respond_to?(:bytesize) ? p.bytesize : p.size
            body_content << p
          end
          [bytes.to_s, body_content]
        end
      end
    end
  end
end
