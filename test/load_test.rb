#!/usr/bin/ruby

# WebROaR - Ruby Application Server - http://webroar.in/
# Copyright (C) 2009  WebROaR
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

require 'yaml'
WEBROAR_ROOT = File.expand_path(File.join(File.dirname(__FILE__),'..'))
conf = YAML::load(File.read(File.join(WEBROAR_ROOT,'conf', 'test_suite_config.yml')))
url = "http://127.0.0.1:#{conf['test_app_configuration']['port']}/test_app/users"
conf = conf['load_test_configuration']
RESULT_FILE_FIX = File.join(File.expand_path(File.dirname(__FILE__)),'load_test_result_fix')
RESULT_FILE_RANDOM = File.join(File.expand_path(File.dirname(__FILE__)),'load_test_result_random')
TEMP_RES_FILE = File.join(File.expand_path(File.dirname(__FILE__)),'temp_result')
LOAD_TEST_SUMMARY = File.join(File.expand_path(File.dirname(__FILE__)),'load_test_summary')

File.truncate(RESULT_FILE_FIX,0) if File.exists?(RESULT_FILE_FIX)
File.truncate(RESULT_FILE_RANDOM,0) if File.exists?(RESULT_FILE_RANDOM)
File.truncate(TEMP_RES_FILE,0) if File.exists?(TEMP_RES_FILE)
File.truncate(LOAD_TEST_SUMMARY,0) if File.exists?(LOAD_TEST_SUMMARY)

test_runs_random = conf['test_runs'].to_i/2
test_runs_fix = conf['test_runs'].to_i - test_runs_random
c = conf['concurrency'].to_i
n = conf['number_of_requests'].to_i
expected_rps = conf['expected_rps'].to_i

failed=0
for i in 1..test_runs_fix
  run = i
  system("echo 'run #{run}' > #{TEMP_RES_FILE}")
  system("echo '=========================================================================' >> #{TEMP_RES_FILE}")
  cmd = "ab -k -c#{c} -n#{n} #{url}"
  system("echo '#{cmd}' >> #{TEMP_RES_FILE}")
  system("#{cmd} >> #{TEMP_RES_FILE}")
  result = File.read(TEMP_RES_FILE)
  complete_req = 0
  actual_rps = 0
  if result =~ /Complete\s+requests:\s+(\d+)/i
    complete_req = $1.to_i
  end
  
  if result =~ /Requests\s+per\s+second:\s+(\d+)[.](\d+)/i
    actual_rps = $1.to_i
  end
  
  if complete_req < n or actual_rps < expected_rps
    failed += 1
  end
  File.open(RESULT_FILE_FIX,"a") do |f|
    f.puts result
  end
  
end
#begin
File.open(LOAD_TEST_SUMMARY,"a") do |f|
  str = "Fix test summary\nTotal test: #{test_runs_fix}\nFailed test: #{failed}\n"
  f.puts str
end
failed=0
for i in 1..test_runs_random
  run = i
  system("echo 'run #{run}' > #{TEMP_RES_FILE}")
  system("echo '=========================================================================' >> #{TEMP_RES_FILE}")
  n = rand(50000) #rand(50000)
  c = rand(50) #rand(50)
  s = rand(1500) #rand(5000)
  if c > n
    t = c
    c = n
    n = t
  end
  next if (c == 0 or n == 0)
  system("echo 'sleep for #{s} seconds' >> #{TEMP_RES_FILE}")
  sleep(s)
  system("echo run started at #{Time.now} >> #{TEMP_RES_FILE}")
  cmd = "ab -k -c#{c} -n#{n} #{url}"
  system("echo '#{cmd}' >> #{TEMP_RES_FILE}")
  system("#{cmd} >> #{TEMP_RES_FILE}")
  system("echo run completed at #{Time.now} >> #{TEMP_RES_FILE}")
  
  result = File.read(TEMP_RES_FILE)
  complete_req = 0
  actual_rps = 0
  if result =~ /Complete\s+requests:\s+(\d+)/i
    complete_req = $1.to_i
  end
  
  if complete_req < n
    failed += 1
  end
  File.open(RESULT_FILE_RANDOM, "a") do |f|
    f.puts result
  end
  
end
File.open(LOAD_TEST_SUMMARY,"a") do |f|
  str = "Random test summary\nTotal test: #{test_runs_random}\nFailed test: #{failed}\n"
  f.puts str
end
#end
