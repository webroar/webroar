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
  module Profiler
    # method_name (Symbol) : name of method to be traced
    # parent_name (Constant) : module/class hierarchy in camelcase which contains the method
    # method_type (String) : instance method or class method under parent
    # execute (Hash) : hash having two options, one option is :before_call having code to be executed 
    # before calling a method(method_name), usually it is initialization of data structures
    # and second option is :after_call having code to be executed after returning from method(method_name), 
    # usually it is filling spent_time in that method or determination of controller/action name.
    def trace_method(method_name, parent_name, method_type,  execute={})
      if method_name.to_s =~ /([=\]><~])$/
        Webroar.log_info("Can not profile #{method_name.to_s}")
        return
      end
      without_profile_name = "without_webroar_profiling_#{method_name}"
      with_profile_name = "with_webroar_profiling_#{method_name}"
      if defined? parent_name
        patch = <<-EOL
        def #{with_profile_name}(*args, &block)
          #{execute[:before_call]}
          t1 =  Time.now
          result = #{without_profile_name}(*args, &block)
          t2 = Time.now
          spent_time = ( t2 - t1) * 1000 #converting into miliseconds. TODO: store seconds directly
          #{execute[:after_call]}
          result
        end
        #         TODO: preserve method visibility
        alias #{without_profile_name} #{method_name}
        alias #{method_name} #{with_profile_name}
        #         if #{parent_name}.private_instance_methods().include?(#{without_profile_name})
        #           private #{method_name}
        #         end
        EOL
        
        case parent_name.class.to_s
        when 'Class'
          case method_type
          when 'i'
            parent_name.class_eval(patch, __FILE__, __LINE__)
          when 'c'
            parent_name.instance_eval(patch, __FILE__, __LINE__)
          end
        when 'Module'
          #p 'inside module'
          parent_name.module_eval {patch }
        end
      else
        raise NameError, "#{parent_name.inspect} is not a valid constant name!"
      end
    end #trace_method

    # :perform_action is an entry point for every request in ActionController, and wraps execution of 
    # controller/action + template rendering for it.
    # :trace_perform_action_equivalent helps in tracing any such method.
    # We will get total time spent in controller/action and name of controller, action with help of this method.
    # It takes following arguments :
    # method_name (Symbol) : name of method to be traced
    # parent_name (Constant) : module/class hierarchy in camelcase which contains the method
    # method_type  (String) : instance method or class method under parent
    def trace_perform_action_equivalent(method_name, parent_name, method_type)
      execute = Hash.new
      code = <<-CODE
      Thread.current[:webroar_profiler] = {:controller_action => [], :database => {}, :rendering => 0.0, :rendering_started => false, :wall_time=>nil, :db_metric_stack => [], :render_metric_stack => [] }
      CODE
      execute[:before_call] = code
      code = <<-CODE
      webroar_cp = self.class.controller_path
      webroar_an = action_name           
      Thread.current[:webroar_profiler][:controller_action] = [webroar_cp, webroar_an, spent_time]      
      Thread.current[:webroar_profiler][:wall_time] = t2
      Webroar::Profiler::MessageDispatcher.instance.log_spent_time(Thread.current[:webroar_profiler])
      Thread.current[:webroar_profiler] = nil
      CODE
      # In :after_call, determining name of controller/action, time spent in that and sending 
      # collected metric on messaging queue.
      execute[:after_call] = code
      trace_method(method_name, parent_name, method_type, execute)
    end

    # Through :render method, ActionController performs template rendering.
    # :trace_render_equivalent helps in tracing any such method.
    # We will get total time spent in rendering with help of this method.
    # It takes following arguments :
    # method_name (Symbol) : name of method to be traced
    # parent_name (Constant) : module/class hierarchy in camelcase which contains the method
    # method_type  (String) : instance method or class method under parent
    def trace_render_equivalent(method_name, parent_name, method_type)
      execute = Hash.new
      code = <<-CODE
      if Thread.current[:webroar_profiler]
        Thread.current[:webroar_profiler][:rendering_started] = true
        Thread.current[:webroar_profiler][:render_metric_stack].push(0.0)     
      end
      CODE
      # One can very well make db calls from template rendering. To find out pure time spent in rendering, 
      # a check has been kept to determine whether rendering is started or not, if started then, time for 
      # that db call is deducted from rendering time. So, there can be negative number in rendering time.
      # In spent_time variable we are geting time spent in rendering template, including db call made from 
      # it, adding it instead of assigning, to rendering time to get pure rendering time.
      # In Rails 2.2.2 there is *render* call, from *render* itself(i.e. recursive call for *render*). We 
      # will count spent_time from the first *render* call only(which give total time in *render*, including 
      # all recursive call)
      execute[:before_call] = code
      code = <<-CODE
      if Thread.current[:webroar_profiler]           
        metric_stack = Thread.current[:webroar_profiler][:render_metric_stack]        
        metric_stack.pop      
        unless metric_stack.size > 0
          Thread.current[:webroar_profiler][:rendering] += spent_time    
          Thread.current[:webroar_profiler][:rendering_started] = false  
        end        
      end
      CODE
      execute[:after_call] = code
      trace_method(method_name, parent_name, method_type, execute)
    end

    # :trace_database_method helps in tracing ORM framework. Currently supporting ActiveRecord.
    # It takes following arguments:
    # method_name (Symbol) : name of method to be traced
    # parent_name (Constant) : module/class hierarchy in camelcase which contains the method
    # method_type  (String) : instance method or class method under parent
    def trace_database_method(method_name, parent_name, method_type)
      execute = Hash.new
      # Session management can be done through ORM, a check(if Thread.current[:webroar_profiler]) has been kept to record spent time only if its been
      # called from controller's method.
      
      # Method1 can call Method2, Method2 can call Method3 and so on..
      # Stack helps in calculating exclusive time spent in each method
      code = <<-CODE
      if Thread.current[:webroar_profiler]                
        db_metric_stack = Thread.current[:webroar_profiler][:db_metric_stack]
        db_metric_stack.push(0.0)
        Thread.current[:webroar_profiler][:db_metric_stack] = db_metric_stack      
      end
      CODE
      execute[:before_call] = code
      if method_type == 'c'
        class_name_key = "key = self.name"
      else
        class_name_key = "key = self.class.name"
      end
      # converting method_name(symbol) into string, to make it work as key, and not a method call
      method_name_key = "'"+method_name.to_s+"'"
#      puts caller.join("\n")   #left over for debugging
#      Checking rendering flag, and deducting db time from rendering time to get pure rendering time.     
#      stack is used to cover following method call-chain possibilities 
#      (I) )A->B->C (II) A->B, A->C->D 
      code = <<-CODE
      if Thread.current[:webroar_profiler]
        #{class_name_key}                
        db_hash = Thread.current[:webroar_profiler][:database]
        db_metric_stack = Thread.current[:webroar_profiler][:db_metric_stack]        
        pop1_time = db_metric_stack.pop
        record_time = spent_time - pop1_time
        if db_metric_stack.size > 0
          pop2_time = db_metric_stack.pop
          db_metric_stack.push(spent_time + pop2_time)
        end        
        unless db_hash[#{method_name_key}]
          db_hash[#{method_name_key}] = Hash.new
        end
        if db_hash[#{method_name_key}][key]
          db_hash[#{method_name_key}][key] += record_time
        else
          db_hash[#{method_name_key}][key] = record_time
        end
        Thread.current[:webroar_profiler][:database] = db_hash
        if Thread.current[:webroar_profiler][:rendering_started] == true
          Thread.current[:webroar_profiler][:rendering] -= record_time
        end
      end
      CODE
      execute[:after_call] = code
      trace_method(method_name, parent_name, method_type, execute)
    end

    module_function(:trace_method, :trace_perform_action_equivalent, :trace_render_equivalent, :trace_database_method)
  end #Profiler
end #Webroar

require File.expand_path(File.join($g_options["webroar_root"], 'src', 'ruby_lib', 'profiler', 'instrumentation', 'instrumentation.rb'))

