#--
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
#++

#This is the model class AppTimeSample related to the application_samples table in the database.
class AppTimeSample < ActiveRecord::Base
  MAX_TRIAL = 3
  class << self
    #This method supplies the url and there statistics to the admin panel application. This data is used for the graph ploting.
    #This method supplies the data for database consumption by an application, throughtput and Average Response Time of an application.


 def get_application_data(app_id, start_time, end_time, type)
      max = 0
      interval = 0
      interval = ((end_time-start_time) / 60).to_i
      final_data = Array.new(interval)
      wall_time = Array.new(interval)
      application_samples = find(:all, :select => 'wall_time, sum(db_time) as db_time,sum(total_time_in_request) as total_time_in_request, sum(number_of_requests) as number_of_requests , avg(avg_response_time) as avg_avg_response_time, avg(peak_requests_served) as avg_peak_requests_served', :conditions => ['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'wall_time')
     application_samples.each do |application_sample| 
          current_time = Time.local(application_sample.wall_time.year, application_sample.wall_time.month, application_sample.wall_time.day, application_sample.wall_time.hour, application_sample.wall_time.min, '0')
         db_time_data = 0
         total_time_in_request = 0
         total_requests = 0
         total_data = 0
         index = (current_time-start_time) / 60
         total_time_in_request = application_sample.total_time_in_request.to_f
         if type == "db"
            db_time_data = application_sample.db_time.to_f
            total_data = (db_time_data.to_f * 100 / total_time_in_request.to_f).to_f
         elsif type == "averageresponsetime"
           total_data = application_sample.avg_avg_response_time.to_f
         elsif type == "throughput"
            total_data = application_sample.avg_peak_requests_served.to_f
         end
         if max < total_data
           max = total_data.to_i
         end
          final_data[index] = total_data
          wall_time[index] = current_time.strftime("%H:%M")
    end  
      for i in 0..interval
          if final_data[i].nil?
            wall_time[i] = (start_time+i*60).strftime("%H:%M")
          end
      end
      max,slab = get_max_and_slab(max)
      step = (interval + 1) / 20
      return wall_time, final_data, max, slab, step
    end
    
    #This method gives the maximum value for y axis and the value by which the y axis is to be partitioned.
    def get_max_and_slab(max)
      if max == 0
        max = 1
        slab = 1
      else
        if max > 8
          slab = max / 8.to_i
        else 
          slab = 1
        end
      end
      max = max.to_i + slab
      return max, slab
    end
    
    #This section of the model is used by the WebROaR Analyzer.
    
    def create_sample(app_id, sample, sampling_rate, wall_time)
      trial = 0
      # peak requests serverd is maximum of number of requests served in a second      
      prs = sample[4].max || 0
      sample[4].reject!{|e| e == 0}
      # time in milisecods /  number of requests
      if sample[4].length > 0
        art = (sample[4].length*1000) / sample[4].inject(0){|sum,e| sum + e}.to_f 
      else
        art = 0
      end
      #      puts 'creating'
      begin 
        create({:app_id => app_id, :total_time_in_request => sample[0], :db_time => sample[1], :rendering_time => sample[2], :number_of_requests => sample[3], :wall_time => wall_time, :sampling_rate => sampling_rate, :avg_response_time => art, :peak_requests_served => prs})
      rescue ActiveRecord::StatementInvalid => e
        if e.message =~ /locked/
          if trial < MAX_TRIAL
            trial += 1
            Webroar::Analyzer::Logger.info "Creating Application Sample - Database is busy try no #{trial}" if defined? Webroar::Analyzer::Logger
            sleep(5)          
            retry
          end
        end
        if defined? Webroar::Analyzer::Logger
          Webroar::Analyzer::Logger.info "Application sample creation for application #{app_id}, wall_time #{wall_time} failed."
          Webroar::Analyzer::Logger.error(e)
          Webroar::Analyzer::Logger.error(e.backtrace.join("\n"))
        end
      rescue Exception => e
        if defined? Webroar::Analyzer::Logger
          Webroar::Analyzer::Logger.error(e) 
          Webroar::Analyzer::Logger.error(e.backtrace.join("\n"))        
          if trial < 1
            sleep(2)
            Webroar::Analyzer::Logger.info "Trying again..."
            trial += 1
            retry
          end
          Webroar::Analyzer::Logger.info "Application sample creation for application #{app_id}, wall_time #{wall_time} failed."
        end
      end
    end
    # application_samples contains at the most one sample and that is for current sampling period.
    # if sample doesn't exists ,create it.
    # if sample exists and wall_time falling in that sampling period, add into sample
    # if sample exists and wall_time not falling in that sampling period and less than sampling period, check into database for that sample and update it
    # if sample exists and wall_time not falling in that sampling period and greater than sampling period, create new sample and add current into database.
    def add_to_sample(message_analyzer, app_id, total_spent_time, db_time, rendering_time, wall_time)
      # create({:app_id => app_id, :total_time_in_request => total_spent_time, :db_time => db_time, :rendering_time => rendering_time, :number_of_requests => 1, :wall_time => wall_time, :sampling_rate => message_analyzer.sampling_rate })       
      if message_analyzer.application_samples[app_id].length == 0        
        message_analyzer.application_samples[app_id] = [wall_time, [total_spent_time, db_time, rendering_time, 1, Array.new(60,0)]]
      elsif wall_time >= message_analyzer.application_samples[app_id].first and wall_time <=  message_analyzer.application_samples[app_id].first + message_analyzer.sampling_rate
        sample = message_analyzer.application_samples[app_id][1]
        sample[0] += total_spent_time
        sample[1] += db_time
        sample[2] += rendering_time
        sample[3] += 1        
        sample[4][wall_time.sec] = (sample[4][wall_time.sec] || 0 ) + 1
        message_analyzer.application_samples[app_id][1] = sample
      elsif wall_time < message_analyzer.application_samples[app_id].first
        db_sample = find(:first, :conditions => ["app_id = ? and wall_time >= ? and wall_time <= ?",app_id, wall_time, wall_time + message_analyzer.sampling_rate])
        if db_sample
          db_sample.total_time_in_request += total_spent_time
          db_sample.db_time += db_time
          db_sample.rendering_time += rendering_time
          db_sample.number_of_requests += 1
          #db_sample.avg_response_time += (total_spent_time / resource_analyzer.worker_count(app_id))
          db_sample.save! rescue nil
        else
          wall_time += message_analyzer.sampling_rate
          create_sample(app_id, [total_spent_time, db_time, rendering_time, 1, [1]], message_analyzer.sampling_rate, wall_time)
          #create({:app_id => app_id, :total_time_in_request => total_spent_time, :db_time => db_time, :rendering_time => rendering_time, :number_of_requests => 1, :wall_time => wall_time, :sampling_rate => message_analyzer.sampling_rate, :avg_response_time => 1000, :peak_requests_served => 1 })
        end
      elsif wall_time > message_analyzer.application_samples[app_id].first +  message_analyzer.sampling_rate
        o_wall_time = message_analyzer.application_samples[app_id].first +  message_analyzer.sampling_rate
        sample = message_analyzer.application_samples[app_id][1]
        
        create_sample(app_id, sample, message_analyzer.sampling_rate, o_wall_time)
        
        message_analyzer.application_samples[app_id] =  [wall_time, [total_spent_time, db_time, rendering_time, 1, Array.new(60,0)]]
      else
        raise UndefinedSituation, "Think of this possibility!"
      end # if
    end #def add_to_sample
    
    # We have kept sampling period of one minute and would keep any sample in memory for maximum one minute. By this method we 			# would write all such samples which are in memory for more than a minute.
    def write_stale_samples(message_analyzer)
      if message_analyzer.application_samples.length == 0
        return
      end
      samples = message_analyzer.application_samples
      samples.each_pair do |app_id, sample|
        if sample and sample.length > 0 and (o_wall_time = sample.first + message_analyzer.sampling_rate) < Time.now
          sample = sample[1]
          create_sample(app_id, sample, message_analyzer.sampling_rate, o_wall_time)
          # peak requests serverd is maximum of number of requests served in a second
          #          prs = sample[4].max
          #          sample[4].reject!{|e| e == 0}
          #          art = sample[4].inject(0){|sum,e| sum + e}.to_f / sample[4].length
          #          create({:app_id => app_id, :total_time_in_request => sample[0], :db_time => sample[1], :rendering_time => sample[2], :number_of_requests => sample[3], :wall_time => o_wall_time, :sampling_rate => message_analyzer.sampling_rate, :avg_response_time  => ars, :peak_requests_served => prs})
          message_analyzer.application_samples[app_id] = Array.new
        end
        
      end
    end # def write_stale_samples
    
    # At time of stopping a script, we would write the samples which are in memory.
    def write_all_samples(message_analyzer)
      if message_analyzer.application_samples.length == 0
        return
      end
      samples = message_analyzer.application_samples
      samples.each_pair do |app_id, sample|
        if sample and sample.length > 0
          o_wall_time = sample.first + message_analyzer.sampling_rate
          sample = sample[1]
          create_sample(app_id, sample, message_analyzer.sampling_rate, o_wall_time)
          # peak requests serverd is maximum of number of requests served in a second
          #          prs = sample[4].max
          #          sample[4].reject!{|e| e == 0}
          #          art = sample[4].inject(0){|sum,e| sum + e}.to_f / sample[4].length
          #          create({:app_id => app_id, :total_time_in_request => sample[0], :db_time => sample[1], :rendering_time => sample[2], :number_of_requests => sample[3], :wall_time => o_wall_time, :sampling_rate => message_analyzer.sampling_rate, :avg_response_time => ars, :peak_requests_served => prs})
        end # 	if sample and sample.length > 0
      end # do |app_id, sample|
    end #def write_all_samples
  end
end
