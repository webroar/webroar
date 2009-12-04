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

###############################################################################
#        Rake file to run integrated test-suit
###############################################################################
require 'spec/rake/spectask'

#TODO: forget underscore and cover tests under namespace
WEBROAR_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
SPEC_DIR = File.join(WEBROAR_ROOT,'test','spec')
REPORT_DIR = File.join(WEBROAR_ROOT,'report')
TEST_DIR = File.join(WEBROAR_ROOT, 'test')
DEBUG_LOG_DIR = File.join(TEST_DIR,'debug_log')
ALL_SPECS = FileList[File.join(SPEC_DIR,'*_spec.rb')].exclude("conditional_spec.rb")
#ALL_SPECS = FileList[File.join(SPEC_DIR,'access_log_spec.rb')]
#ALL_SPECS = FileList[File.join(SPEC_DIR,'*_spec.rb')].exclude(
#File.join(SPEC_DIR,'host_name_spec.rb'),
#File.join(SPEC_DIR,'connection_keep_alive_spec.rb'),
#File.join(SPEC_DIR,'webroar_command_spec.rb'),
#File.join(SPEC_DIR,'content_encoding_spec.rb'),
#File.join(SPEC_DIR,'heart_beat_spec.rb'),
#File.join(SPEC_DIR,'http_request_parser_spec.rb'),
#File.join(SPEC_DIR, 'access_log_spec.rb'),
#File.join(SPEC_DIR, 'conditional_spec.rb'),
#File.join(SPEC_DIR, 'http_spec.rb'),
#File.join(SPEC_DIR, 'analytics_spec.rb')
#)
require File.join(SPEC_DIR,'spec_helper.rb')

test_flag = 1

desc "Build .so file for all the test written in c"
task :build_tests do
  create_directories([TEST_OBJ_DIR])
  test_files = FileList[File.join(UNIT_TEST_DIR, '*.c'), File.join(HELPER_DIR, '*.c'),
  File.join(YAML_DIR, '*.c')]
  test_obj = {}
  test_files.each do |sfn|
    obj = sfn.sub(/\.[^.]*$/, '.o')
    obj_file = File.join(TEST_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
    test_obj[obj_file]=sfn
  end
  
  unless $webroar_config_called
    webroar_config
  end
  
  test_obj.each { |obj_file,src_file|
    cmd = "#{COMPILER}  #$inc_flags  #$CFLAGS #$flags #$debug_flags -c #{src_file} -o #{obj_file}"
    sh cmd
  }
  
  tests_obj_files = FileList[File.join(TEST_OBJ_DIR,"*.o")]
  out_file = File.join(UNIT_TEST_DIR, 'test_ext.so')
  cmd = "#{COMPILER} #$libs #{tests_obj_files} -shared -o #{out_file}"
  sh cmd
end

desc "Build and executes unit test"
task :unit_test do
  test_file = File.join(UNIT_TEST_DIR, 'test.log')
  summary_file = File.join(UNIT_TEST_DIR, 'test_summary')
  File.truncate(test_file, 0) if File.exists?(test_file)
  File.truncate(summary_file, 0) if File.exists?(summary_file)
  
  print "Compiling unit test cases ... "
  system("rake build_tests >#{File.join(UNIT_TEST_DIR,'testcases.log')} 2>>#{File.join(UNIT_TEST_DIR,'testcases.log')}")
  if($?==0)
    puts "Done."
    system("rake clean >>#{File.join(UNIT_TEST_DIR,'testcases.log')} 2>>#{File.join(UNIT_TEST_DIR,'testcases.log')}")
    puts "Running test cases ..."
    puts ""
    $LOAD_PATH.unshift(UNIT_TEST_DIR)
    require 'test_ext'
    Dir.chdir(UNIT_TEST_DIR)
    Test::Test.run
    puts "\nPlease refer 'test\\unit\\test.log' for the detailed report."
  else
    puts "Compilation error. Please refer 'testcases.log' for details."
  end
  Dir.chdir(WEBROAR_ROOT)
  return unless File.exists?(test_file)
  
  result = File.read(test_file)
  
  passed = 0
  failed = 0
  p_f = result.scan(/Test\s*passed\s*:\s*(\d+),\s*Test\s*failed\s*:\s*(\d+)/)
  p_f.each do |e|
    passed += e[0].to_i
    failed += e[1].to_i
  end
  str = "Unit test summary\nTotal test: #{passed+failed}\nFailed test: #{failed}\n"
  
  File.open(summary_file, "w") do |f|
    f.puts str
  end
end

task :test_setup do
  if ENV["debug_build"] == "yes"
    rv = test_setup(true)
  else
    rv = test_setup()
  end
  if rv == -1
    puts " * Some problem occured in test setup. Exiting. * "
    test_flag = 0
    # return -1
    exit(-1)
  end
end

desc "Executes functional test"
task :spec => :test_setup
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = ALL_SPECS
  #t.spec_opts << "--format specdoc:#{TEST_RESULT}"
end


desc "Executes Admin-panel test"
task :admin_panel_test do
  puts "Executing Admin-panel tests ..."
  Dir.chdir(File.join(WEBROAR_ROOT,'src','admin_panel'))
  system("rake test RAILS_ENV=test >test.log 2>error.log")
  result = File.read('test.log')
  p_f = result.scan(/(\d+)\s+tests,\s+\d+\s+assertions,\s+(\d+)\s+failures,\s+(\d+)\s+errors/)
  total = 0
  failed = 0
  error = 0
  p_f.each do |e|
    total += e[0].to_i
    failed += e[1].to_i
    error += e[2].to_i
  end
  str = "Admin-panel test summary\nTotal test: #{total}\nFailed test: #{failed}\nError: #{error}\n"
  File.open('test_summary',"w") do |f|
    f.puts str
  end
  Dir.chdir(WEBROAR_ROOT)
end

desc "Load testing by ab tool"
task :load_test do
  puts "Executing load tests ..."
  begin
    create_config({},{'baseuri' => '/test_app', 'max_worker' => 6})
    move_config
    create_messaging_config
    move_messaging_config
    start_server
    sleep(15)
    system("ruby #{File.join(TEST_DIR,'load_test.rb')}")
    stop_server
  rescue Exception => e
  ensure
    remove_config
    remove_messaging_config
  end
end


desc "Build gem"
task :build do
  cmd = "rm -fr pkg/* 2>> build_test.log >>build_test.log"
  system(cmd)
  t = Rake::Task[:gem]
  t.invoke()
end

desc "Gem install. It's meant for automated testing, passing predefined values for required inputs"
task :build_install do
  gem_file = File.join(WEBROAR_ROOT,'pkg',"webroar-#{Webroar::VERSION::STRING}.gem")
  return -1 unless File.exists?(gem_file)
  print "Installing gem ... "
  cmd = "gem install #{gem_file} 2>> build_test.log >>build_test.log"
  system(cmd)
  if($?==0)
    puts "Done"
    print "Installing WebROaR ... "
    cmd = "webroar install 2>> build_test.log >>build_test.log << **\nadmin\nimpetus\nimpetus\n\n**"
    system(cmd)
    if($?==0)
      puts "Done"
    else
      test_flag = 0
      puts "Failed"
    end
  else
    test_flag = 0
    puts "Failed"
  end
  
end

desc "Uninstall server and its gem"
task :build_uninstall do
  print "Uninstalling WebROaR ... "
  cmd = "webroar uninstall 2>> build_test.log >>build_test.log"
  system(cmd)
  if($?==0)
    puts "Done"
  else
    puts "Failed"
  end
  #puts "server uninstall $? = #$?"
  print "Uninstalling gem ..."
  cmd = "gem uninstall webroar -v #{Webroar::VERSION::STRING} -x 2>> build_test.log >>build_test.log << **\ny\n** "
  system(cmd)
  if($?==0)
    puts "Done"
  else
    puts "Failed"
  end
  
  #  puts "gem uninstall $? = #$?"
end

desc "Build test"
task :build_test do
  puts "Executing build tests ..."
  build_test = File.join(TEST_DIR,'build_test')
  build_test_summary = File.join(TEST_DIR,'build_test_summary')
  exception_log = File.join(TEST_DIR,'exception.log')
  File.truncate('build_test.log', 0) if File.exists?('build_test.log')
  
  Dir.chdir(WEBROAR_ROOT)
  File.truncate(build_test,0) if File.exists?(build_test)
  File.truncate(build_test_summary, 0) if File.exists?(build_test_summary)
  total = 0
  failed = 0
  bf = File.open(build_test,'w')
  bf.print "Build gem ... "
  total += 1
  t = Rake::Task[:build]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #  puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Done"
  end
  
  bf.print "Install gem and server ... "
  total += 1
  t = Rake::Task[:build_install]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #   puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Pass"
  end
  
  bf.print "Uninstall server and gem ... "
  total += 1
  t = Rake::Task[:build_uninstall]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #   puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Pass"
  end
  
  bf.puts "#{total} total, #{failed} failed\n"
  bf.close
  
  str = "Build test summary\nTotal test: #{total}\nFailed test: #{failed}\n"
  File.open(build_test_summary,"w") do |f|
    f.puts str
  end
end

def check_and_copy(src_file, dest_file)
  if File.exists?(src_file)
    FileUtils.copy(src_file, dest_file)
  end
end

def test_cleanup(report_dir)
  
  unless File.exists?(report_dir)
    FileUtils.mkdir_p(report_dir)
  end
  
  # copy unit tests related files
  check_and_copy(File.join(UNIT_TEST_DIR,'test_summary'), File.join(report_dir, 'unit-test-summary'))
  check_and_copy(File.join(UNIT_TEST_DIR, 'testcases.log'), File.join(report_dir, 'unit-testcase.log'))
  check_and_copy(File.join(UNIT_TEST_DIR, 'test.log'), File.join(report_dir, 'unit-test.log'))
  
  # copy admin-panel tests related files
  check_and_copy(File.join(WEBROAR_ROOT,'src', 'admin_panel', 'test.log'), File.join(report_dir, 'admin-panel-test.log'))
  check_and_copy(File.join(WEBROAR_ROOT,'src', 'admin_panel', 'error.log'), File.join(report_dir, 'admin-panel-error.log'))
  check_and_copy(File.join(WEBROAR_ROOT,'src', 'admin_panel', 'test_summary'), File.join(report_dir, 'admin-panel-test-summary'))
  
  # copy functional tests related files
  check_and_copy(File.join(SPEC_DIR, 'test.log'), File.join(report_dir, 'spec-test.log'))
  check_and_copy(File.join(SPEC_DIR, 'test_summary'), File.join(report_dir, 'spec-test-summary'))
  check_and_copy(File.join(SPEC_DIR, 'setup.log'), File.join(report_dir, 'spec-test-setup.log'))
  check_and_copy(File.join(SPEC_DIR, 'test-run.log'), File.join(report_dir, 'spec-test-run.log'))
  
  # copy load tests related files
  check_and_copy(File.join(TEST_DIR, 'load_test_summary'), File.join(report_dir, 'load-test-summary'))
  check_and_copy(File.join(TEST_DIR, 'load_test_result_fix'), File.join(report_dir, 'load-test-result-fix'))
  check_and_copy(File.join(TEST_DIR, 'load_test_result_random'), File.join(report_dir, 'load-test-result-random'))
  
  # copy exception.log
  check_and_copy(File.join(TEST_DIR, 'exception.log'), File.join(report_dir, 'exception.log.1'))
  
  #copy database file
  check_and_copy(File.join(WEBROAR_ROOT, 'src', 'admin_panel', 'db', 'webroar_test.sqlite3'), report_dir)
  
  # copy debug_log files
  if ENV["debug_build"] == "yes"
    dest_debug_log_dir = File.join(report_dir, 'debug_log')
    unless File.exists?(dest_debug_log_dir)
      FileUtils.mkdir_p(dest_debug_log_dir)
    end
    log_file_pattern = File.join(DEBUG_LOG_DIR,'*')
    log_files = Dir.glob(log_file_pattern)
    for file in log_files
      FileUtils.cp(file,dest_debug_log_dir)
    end
  end
end

desc "Integrated testing executes unit tests, admin-panel tests and functional \
      tests. To run load tests give load_test=yes, to run build tests give \
      build_test=yes as an argument. To run test under debug build give \
      debug_build=yes as an argument."
task :all_test do
  
  if ENV["debug_build"] == "yes"
    # Clear log files.
    system("webroar clear")
    unless File.exists?(LOG_FILES)
      FileUtils.mkdir_p(LOG_FILES)
    end
  end
  
  exception_log = File.join(TEST_DIR,'exception.log')
  File.truncate(exception_log,0) if File.exists?(exception_log)
  
  if(test_flag==1)
    t = Rake::Task[:unit_test]
    begin
      t.invoke()
    rescue Exception => e
      File.open(exception_log,"a") do |f|
        f.puts e
        f.puts e.backtrace
      end
    end
  end
  
  if(test_flag==1)
    t = Rake::Task[:spec]
    puts "Executing functional tests ..."
    begin      
      ENV["SPEC_OPTS"] = "--format specdoc:#{TEST_RESULT}"
      t.invoke()
    rescue Exception => e
      File.open(exception_log,"a") do |f|
        f.puts e
        f.puts e.backtrace
      end
    ensure
      if File.exists?(TEST_RESULT)
        system("tail -2 #{File.join(SPEC_DIR,'test.log')} > #{File.join(SPEC_DIR,'test_summary')}")
        result = File.read(File.join(SPEC_DIR,'test_summary'))
        total = 0
        failed = 0
        if result =~  /(\d+)\s*(example|examples),\s*(\d+)\s*failure/
          total = $1
          failed = $3
        end
        str = "Functional test summary\nTotal test: #{total}\nFailed test: #{failed}\n"
        File.open(File.join(SPEC_DIR,'test_summary'),"w") do |f|
          f.puts str
        end
      end
      
      if ENV["debug_build"] == "yes"
        unless File.exists?(DEBUG_LOG_DIR)
          FileUtils.mkdir_p(DEBUG_LOG_DIR)
        end
        log_file_pattern = File.join(LOG_FILES,'*.log')
        log_files = Dir.glob(log_file_pattern)
        for file in log_files
          FileUtils.cp(file,File.join(DEBUG_LOG_DIR,"#{File.basename(file)}.spec"))
        end
        cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} clear"
        system(cmd)
      end
    end
  end
  
  if(test_flag==1)
    t = Rake::Task[:admin_panel_test]
    begin
      t.invoke()
    rescue Exception => e
      File.open(exception_log,"a") do |f|
        f.puts e
        f.puts e.backtrace
      end
    end
  end
  
  if test_flag==1 and ENV["load_test"] == 'yes'
    t = Rake::Task[:load_test]
    begin
      t.invoke()
    rescue Exception => e
      File.open(exception_log,"a") do |f|
        f.puts e
        f.puts e.backtrace
      end
    end
  end
  
  if test_flag==1 and ENV["build_test"] == "yes"
    t = Rake::Task[:build_test]
    begin
      t.invoke()
    rescue Exception => e
      File.open(exception_log,"a") do |f|
        f.puts e
        f.puts e.backtrace
      end
    end
  end
  
  if(ENV["report_dir"])
    test_cleanup(ENV["report_dir"])
  end
  
  unless ENV["no_report"]
    test_report(ENV["report_dir"])
  end
  
end

#task :all_test => [:unit_test, :admin_panel_test, :spec, :load_test]

def test_report(report_dir)
  total = 0
  failed = 0
  f = File.open(File.join(report_dir,'test-summary'),"w")
  f.puts "------------------------------------------------------------------------------"
  fmt = "%*s%*s%*s"
  str = fmt % [-58,'Type',10,'Total',10,'Failed']
  f.puts str
  f.puts "-------------------------------------------------------------------------------"
  if File.exists?(File.join(report_dir,'unit-test-summary'))
    result = File.read(File.join(report_dir,'unit-test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, 'Unit Tests',10,$1,10,$2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(report_dir,'admin-panel-test-summary'))
    result = File.read(File.join(report_dir,'admin-panel-test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)\s*Error:\s*(\d+)/m
    str = fmt % [-58, 'Admin Panel Tests',10,$1,10,$2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(report_dir,'spec-test-summary'))
    result = File.read(File.join(report_dir,'spec-test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, 'Functional Tests', 10, $1, 10, $2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(report_dir,'load-test-summary'))
    result = File.read(File.join(report_dir,'load-test-summary'))
    res = result.scan(/Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)\s*/m)
    str = fmt % [-58, "Load Test I - Continuous Run", 10, res[0][0], 10, res[0][1]]
    f.puts str
    str = fmt % [-58, 'Load test II - Random Sleep Intervals', 10, res[1][0], 10, res[1][1]]
    f.puts str
    total += res[0][0].to_i + res[1][0].to_i
    failed += res[0][1].to_i + res[1][1].to_i
  end
  
  if File.exists?(File.join(TEST_DIR,'build_test_summary'))
    result = File.read(File.join(TEST_DIR,'build_test_summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, "Build Tests", 10, $1, 10, $2]
    f.puts str
    f.puts "\n"
    total += $1.to_i
    failed += $2.to_i
  end
  f.close
  
  f = File.open(File.join(report_dir,'test-report'),"w")
  f.puts File.read(File.join(report_dir,'test-summary')) if File.exists?(File.join(report_dir,'test-summary'))
  
  if File.exists?(File.join(report_dir,'unit-test.log'))
    f.puts "-------------------------------Unit Tests Result--------------------------------"
    f.puts File.read(File.join(report_dir,'unit-test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(report_dir,'admin-panel-test.log'))
    f.puts "-----------------------------Admin Panel Tests Result---------------------------"
    f.puts File.read(File.join(report_dir, 'admin-panel-test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(report_dir,'spec-test.log'))
    f.puts "------------------------------Functional Tests Result---------------------------"
    f.puts File.read(File.join(report_dir,'spec-test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(report_dir,'load-test-result-fix'))
    f.puts "---------------------------Load Test I - Continuous Run-------------------------"
    f.puts File.read(File.join(report_dir,'load-test-result-fix'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(report_dir,'load-test-result-random'))
    f.puts "------------------------Load test II - Random Sleep Intervals-------------------"
    f.puts File.read(File.join(report_dir,'load-test-result-random'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(TEST_DIR,'build_test'))
    f.puts "--------------------------------Build Tests Result------------------------------"
    f.puts File.read(File.join(TEST_DIR,'build_test'))
    f.puts "\n"
  end
  
  f.close
  
  f = File.open(File.join(report_dir,"test-result"),"w")
  if total == 0 and failed == 0
    f.puts "Could not be executed at all"
  elsif total == failed
    f.puts "All tests failed"
  elsif failed != 0
    f.puts "Some tests failed"
  else
    f.puts "All tests passed"
  end
  f.close
  
end

desc "Runs integrated test-suit comprises of gem creation, installation, unit \
      tests, admin-panel tests, functional tests. To run load tests give \
      load_test=yes as an argument. To run under debug build give debug_build=\
      yes as an argument."
task :test do
  exception_log = File.join(TEST_DIR,'exception.log')
  File.truncate(exception_log,0) if File.exists?(exception_log)
  
  build_test = File.join(TEST_DIR,'build_test')
  build_test_summary = File.join(TEST_DIR,'build_test_summary')
  exception_log = File.join(TEST_DIR,'exception.log')
  
  Dir.chdir(WEBROAR_ROOT)
  File.truncate(build_test,0) if File.exists?(build_test)
  File.truncate(build_test_summary, 0) if File.exists?(build_test_summary)
  total = 0
  failed = 0
  bf = File.open(build_test,'w')
  bf.print "Build gem ... "
  total += 1
  t = Rake::Task[:build]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #  puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Pass"
  end
  
  bf.print "Install gem and server ... "
  total += 1
  t = Rake::Task[:build_install]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #   puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Pass"
  end
  
  str = "-n "
  
  if ENV["debug_build"] == "yes"
    str += "-d "
  end
  
  if ENV["load_test"] == "yes"
    str += "-l"
  end
  
  # Run tests on installed directory. Copy test-report and test-summary to TEST_DIR
  cmd = "webroar test -r=#{REPORT_DIR} #{str}"
  system(cmd)
  
  bf.print "Uninstall server and gem ... "
  total += 1
  t = Rake::Task[:build_uninstall]
  begin
    t.invoke()
  rescue Exception => e
    File.open(exception_log,"a") do |f|
      f.puts e
      f.puts e.backtrace
    end
  end
  #   puts "$? = #$?"
  unless $? == 0
    failed += 1
    bf.puts "Failed"
  else
    bf.puts "Pass"
  end
  
  bf.puts "#{total} total, #{failed} failed\n"
  bf.close
  
  str = "Build test summary\nTotal test: #{total}\nFailed test: #{failed}\n"
  File.open(build_test_summary,"w") do |f|
    f.puts str
  end
  
  test_report(REPORT_DIR)
end

#desc "Integration testing and test-suite summary, report and one line result."
#task :test => [:all_test, :test_report]
