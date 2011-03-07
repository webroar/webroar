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

#This is the model class UrlTimeSample related to the url_samples table in the database.
class UrlTimeSample < ActiveRecord::Base
  extend Webroar::Analyzer::WithExceptionHandling if defined? Webroar::Analyzer::WithExceptionHandling
  belongs_to :app 
  class << self
    # This method returns a hash of data for the graphs Url HIts , Slowest Url and 
    # Most time Consuming Url for an application.
    def get_url_calls_data(app_id, from_date, to_date, type)
      max = 0
      urls = Array.new
      final_data = Array.new
      start_time = from_date.strftime("%Y-%m-%d") + " 00:00:00"
      end_time = to_date.strftime("%Y-%m-%d") + " 23:59:59"
      if type == "requests"
        url_samples = get_url_hits_data(app_id, start_time, end_time)
      elsif type == "slowesturl"
        url_samples = get_slowest_url_data(app_id, start_time, end_time)
      elsif type == "timeconsumingurl"
        url_samples = get_time_consuming_url_data(app_id, start_time, end_time)
      else
        url_samples = get_top_db_consuming_url_data(app_id, start_time, end_time)
      end
      if url_samples.size > 0
        url_samples.each do |url_sample|
          urls << url_sample.url
          if type == "requests"
            data = url_sample.requests.to_i
          elsif type == "slowesturl"
            data = url_sample.result.to_i
          elsif type == "timeconsumingurl"
            data = url_sample.time.to_f/1000
          else
            data = url_sample.time.to_f/1000
          end
          final_data << data
          if max <  data
            max = data
          end
        end
        if urls.size < 15
          for i in 0..14 - urls.size
            urls << ""
            final_data << 0
          end
        else
          urls = urls[0..14]
          final_data = final_data[0..14]
        end
      end
      max, slab = get_max_and_slab(max)
      return urls, final_data, max, slab
    end
    
    #This method is get data of the url hits for an application. This method is called by the get_url_calls_data method.
    def get_url_hits_data(app_id, start_time, end_time)
      url_samples = find(:all, :select => 'url, sum(number_of_requests) as requests', :conditions => ['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'url', :order => 'requests desc')
      return	url_samples
    end
    
    #This method is get data of the slowest urls of an application. This method is called by the get_url_calls_data method.
    def get_slowest_url_data(app_id, start_time, end_time)
      url_samples = find(:all, :select=>'url, (sum(total_time) / sum(number_of_requests)) as result', :conditions => ['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'url', :order => 'result desc')
      return	url_samples
    end
    
    #This method is get data of the time consuming urls of an application. This method is called by the get_url_calls_data method.
    def get_time_consuming_url_data(app_id, start_time, end_time)
      url_samples = find(:all, :select => 'url, sum(total_time) as time', :conditions=>['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'url', :order => 'time desc')
      return	url_samples
    end
    
    #This method is get data of the top database consuming urls of an application. This method is called by the get_url_calls_data method.
    def get_top_db_consuming_url_data(app_id, start_time, end_time)
      url_samples = find(:all, :select => 'url, sum(db_time) as time', :conditions=>['app_id = ? and wall_time >= ? and wall_time < ?', app_id, start_time, end_time], :group => 'url', :order => 'time desc')
      return url_samples
    end
    
    #This method gives the maximum value for y axis and the value by which the y axis is to be partitioned.
    def get_max_and_slab(max)
      if max == 0
        max = 1
        slab = 1
      else
        if max > 8
          slab = (max / 8.to_i).to_i
        else
          slab = 1
        end
      end
      max = max.to_i + slab
      return max, slab
    end
    
    #This method returns the array of the url for an application that were hit between start_time and end_time
    def get_urls(start_time, end_time, app_id)      
      urls = Array.new
      url_samples = UrlTimeSample.find:all, :select=>'id, url, sum(total_time) as time', :conditions => ['app_id = ? and wall_time >= ? and wall_time < ?', app_id,  start_time, end_time], :group => 'url', :order => 'time desc'
      url_samples.each do |url_sample|
        urls << url_sample.url
      end
      return urls
    end
    
    # This method returns the total_time, db_time and rendering time for an url of an application 
    # for the given period between start_time and end_time
    def get_url_data(start_time, end_time, app_id, url_name)
      url_samples=UrlTimeSample.find:all, :select=>'sum(total_time) as total_time, sum(db_time) as db_time, sum(rendering_time) as rendering_time, sum(number_of_requests) as requests', :conditions => ['app_id = ? and url = ? and wall_time >= ? and wall_time < ?', app_id, url_name, start_time, end_time]
      return url_samples
    end
    
    # This method returns the array of the url ids for a particular url of an application 
    # that was hit in a period between start_time and end_time
    def get_url_id(start_time, end_time, url_name,app_id)
      url_samples = UrlTimeSample.find:all, :select => 'id, url', :conditions => ['url = ? and app_id = ? and wall_time >= ? and wall_time < ?', url_name, app_id, start_time, end_time]
      return url_samples
    end
    
    
    #This section of the model is used by the Webraor Analyzer.
    
    def create_sample(app_id, url, sample, wall_time, sampling_rate, db_time_breakup)
      url_sample = nil
      with_exception_handling("URL sample creation for application #{app_id}, URL #{url}, wall_time #{wall_time}") do
        url_sample =  create({:app_id => app_id, :url => url, :total_time => sample[0], :db_time => sample[1], :rendering_time => sample[2], :number_of_requests => sample[3], :wall_time => wall_time, :sampling_rate => sampling_rate})
      end
      if url_sample.id and db_time_breakup
        db_time_breakup.each_pair do |key, value|
          create_breakup_sample(app_id, url_sample.id, key, value, wall_time)  
        end
      end
    end
    
    def create_breakup_sample(app_id, url_sample_id, key, value, wall_time)
      with_exception_handling("URL breakup sample creation for application #{app_id}, url_sample_id #{url_sample_id}, wall_time #{wall_time} failed.") do
        UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample_id, :method_name => key, :spent_time => value, :wall_time => wall_time})
      end            
    end
    
    # url_samples contain at most one sample per url in the scope of application.
    # create url sample if not present
    # if url presents, and wall_time falling in sampling period, add it
    # if url presents, and wall_time not falling in sampling period and less than sampling period, check into database for that sample and update it
    # if url presents, and wall_time not falling in sampling period and greater than sampling period, create new sample and insert current into database.
    def add_to_sample( message_analyzer, app_id, url, total_spent_time, db_time, rendering_time, db_time_breakup, wall_time)
      if message_analyzer.url_samples[app_id][url] == nil
        message_analyzer.url_samples[app_id][url] = [wall_time, [ total_spent_time, db_time, rendering_time, 1]] #one more element(as a hash) come in last position for keeping db_breakup time
        message_analyzer.url_samples[app_id][url][1][4] = db_time_breakup.dup
      elsif wall_time >= message_analyzer.url_samples[app_id][url].first and wall_time <= message_analyzer.url_samples[app_id][url].first + message_analyzer.sampling_rate
        sample = message_analyzer.url_samples[app_id][url][1]
        sample[0] += total_spent_time
        sample[1] += db_time
        sample[2] += rendering_time
        sample[3] += 1
        tmp_hash = sample[4]
        db_time_breakup.each_pair do |key, value|
          if tmp_hash[key]
            tmp_hash[key] += value
          else
            tmp_hash[key] = value
          end
        end
        sample[4] = tmp_hash
        message_analyzer.url_samples[app_id][url][1] = sample
      elsif wall_time < message_analyzer.url_samples[app_id][url].first
        url_sample = find(:first, :conditions => ["app_id = ? and url = ? and wall_time >= ? and wall_time <= ?",app_id, url, wall_time, wall_time + message_analyzer.sampling_rate])
        if url_sample
          url_breakup_sample = UrlBreakupTimeSample.find(:all, :conditions => ["url_sample_id = ?",url_sample.id])
          url_sample.total_time += total_spent_time
          url_sample.db_time += db_time
          url_sample.rendering_time += rendering_time
          url_sample.number_of_requests += 1
          url_sample.save! rescue nil
        db_breakup_keys = db_time_breakup.keys
          covered_keys = []
          url_breakup_sample.each do |breakup|
            if db_breakup_keys.include?(breakup.method_name)
              breakup.spent_time += db_time_breakup[breakup.method_name]
              breakup.save! rescue nil
            covered_keys.push(breakup.method_name)
            end
          end
          remaining_keys = db_breakup_keys - covered_keys
          remaining_keys.each do |key|
            UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample.id, :method_name => key, :spent_time => db_time_breakup[key], :wall_time => url_sample.wall_time}) rescue nil
          end
        else
          wall_time += message_analyzer.sampling_rate
          create_sample(app_id, url, [total_spent_time, db_time, rendering_time, 1], wall_time, message_analyzer.sampling_rate, db_time_breakup)
          #url_sample = create({:app_id => app_id, :url => url, :total_time => total_spent_time, :db_time => db_time, :rendering_time => rendering_time, :number_of_requests => 1, :wall_time => wall_time, :sampling_rate => message_analyzer.sampling_rate})
          #db_time_breakup.each_pair do |key, value|
          #  UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample.id, :method_name => key, :spent_time => value, :wall_time => url_sample.wall_time})
          #end
        end # if url_sample
      elsif wall_time > message_analyzer.url_samples[app_id][url].first + message_analyzer.sampling_rate
        o_wall_time = message_analyzer.url_samples[app_id][url].first + message_analyzer.sampling_rate
        sample = message_analyzer.url_samples[app_id][url][1]
        create_sample(app_id, url, sample, wall_time, message_analyzer.sampling_rate, sample[4])
        #        url_sample = create({:app_id => app_id, :url => url, :total_time => sample[0], :db_time => sample[1], :rendering_time => sample[2], :number_of_requests => sample[3], :wall_time => o_wall_time, :sampling_rate => message_analyzer.sampling_rate})
        #        tmp_hash = sample[4]
        #        tmp_hash.each_pair do |key, value|
        #          UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample.id, :method_name => key, :spent_time => value, :wall_time => url_sample.wall_time})
        #        end
        message_analyzer.url_samples[app_id][url] = [wall_time, [ total_spent_time, db_time, rendering_time, 1]]
        message_analyzer.url_samples[app_id][url][1][4] = db_time_breakup.dup
      else
        raise UndefinedSituation, "Think of this possibility!"
      end # if
    end # def add_to_sample
    
    # We have kept sampling period of one minute and would keep any sample in memory for maximum one minute. By this method we 			# would write all such samples which are in memory for more than a minute.
    def write_stale_samples(message_analyzer)
      if message_analyzer.url_samples.length == 0
        return
      end
      # it will contain all the url samples for all the application.
      all_samples = message_analyzer.url_samples
      all_samples.each_pair do |app_id, app_samples|
        if app_samples.length != 0
          app_samples.each_pair do |url, sample|
            if sample and sample.length > 0 and (o_wall_time = sample.first + message_analyzer.sampling_rate) < Time.now
              tmp_sample = sample[1]
              create_sample(app_id, url, tmp_sample, o_wall_time, message_analyzer.sampling_rate, tmp_sample[4])
              #url_sample = create({:app_id => app_id, :url => url, :total_time => tmp_sample[0], :db_time => tmp_sample[1], :rendering_time => tmp_sample[2], :number_of_requests => tmp_sample[3], :wall_time => o_wall_time, :sampling_rate => message_analyzer.sampling_rate})
              #tmp_hash = tmp_sample[4]
              #if tmp_hash and tmp_hash.length > 0
              #  tmp_hash.each_pair do |key, value|
              #    UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample.id, :method_name => key, :spent_time => value, :wall_time => url_sample.wall_time})
              #  end # do |key, value|
              #end
              app_samples[url] = nil
            end # if (o_wall_time = url_sample.first + message_analyzer.sampling_rate) < Time.now
          end # do |url, sample|
        end # if app_samples.length != 0
      end # do |app_id, app_samples|
    end #def write_stale_samples
    
    # At time of stopping a script, we would write the samples which are in memory.
    def write_all_samples(message_analyzer)      
      if message_analyzer.url_samples.length == 0
        return
      end
      
      # it will contain all the url samples for all the application.
      all_samples = message_analyzer.url_samples
      all_samples.each_pair do |app_id, app_samples|
        if app_samples.length != 0
          app_samples.each_pair do |url, sample|
            if sample and sample.length > 0
              o_wall_time = sample.first + message_analyzer.sampling_rate
              tmp_sample = sample[1]
              create_sample(app_id, url, tmp_sample, o_wall_time, message_analyzer.sampling_rate, tmp_sample[4])
              #url_sample = create({:app_id => app_id, :url => url, :total_time => tmp_sample[0], :db_time => tmp_sample[1], :rendering_time => tmp_sample[2], :number_of_requests => tmp_sample[3], :wall_time => o_wall_time, :sampling_rate => message_analyzer.sampling_rate})
              #tmp_hash = tmp_sample[4]
              #p tmp_hash
              #if tmp_hash and tmp_hash.length > 0
              #  tmp_hash.each_pair do |key, value|
              #    UrlBreakupTimeSample.create({:app_id => app_id, :url_sample_id => url_sample.id, :method_name => key, :spent_time => value, :wall_time => url_sample.wall_time})
              #  end # do |key, value|
              #end
            end
          end # do |url, sample|
        end # if app_samples.length != 0
      end # do |app_id, app_samples|
    end #def write_all_samples
    
  end
end
