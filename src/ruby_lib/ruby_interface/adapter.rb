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
  #inspired from merb
  module Adapter
    class <<self
      # id<String>:: The identifier of the Rack adapter class to retrieve.
      # ===Returns.
      # Class:: The adapter class.
      def get(id)
        #its according to constantize method of ActiveSupport::Inflector
        camel_cased_word = @adapters[id]
        unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
          Webroar.log_error("#{camel_cased_word.inspect} is not a valid constant name!")
        end
        Object.module_eval("::#{$1}", __FILE__, __LINE__)
      end

      # Registers a new Rack adapter.
      # ==== Parameters
      # id<String>:: Identifiers by which this adapter is recognized by.
      # adapter_class<Class>:: The Rack adapter class.
      def register(id, adapter_class)
        @adapters ||= Hash.new
        @adapters[id] = "Webroar::Adapter::#{adapter_class}"
      end
    end # self
    Adapter.register('rails','Rails')
    Adapter.register('rack','Rack')
    #Adapter.register('merb','Merb')
    #Adapter.register('ramaze','Ramaze')
    #Adapter.register('mack','Mack')
  end # Adapter
end # Webroar
