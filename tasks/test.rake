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

#TODO: forget underscore and cover tests under namespace
WEBROAR_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
SPEC_DIR = File.join(WEBROAR_ROOT,'test','spec')
TEST_DIR = File.join(WEBROAR_ROOT, 'test')

DEBUG_LOG_DIR = File.join(TEST_DIR,'debug_log')
ALL_SPECS = FileList[File.join(SPEC_DIR,'*_spec.rb')].exclude(
  File.join(SPEC_DIR, 'conditional_spec.rb')
)


test_flag = 1
total = 0
failed = 0
file = nil

#desc "Log exceptions."
task :log_exception, :exception do |t, args|
  exception_log = File.join(REPORT_DIR,'exception.log')

  File.open(exception_log,"a") do |f|
    f.puts args.exception
    f.puts args.exception.backtrace
  end
end

#desc "Creates required folders for running test cases."
task :create_test_dirs do
  begin
    require 'spec/rake/spectask'
    require File.join(SPEC_DIR,'spec_helper.rb')
  
    if(ENV["report_dir"])
      REPORT_DIR = ENV["report_dir"]
    else
      REPORT_DIR = File.join(WEBROAR_ROOT,'report')
    end

    # make exception.log empty.
    exception_log = File.join(REPORT_DIR,'exception.log')
    File.truncate(exception_log,0) if File.exists?(exception_log)
    
    UNIT_TEST_REPORT = File.join(REPORT_DIR, 'unit_test')
    SPEC_TEST_REPORT = File.join(REPORT_DIR, 'spec')
    ADMIN_TEST_REPORT = File.join(REPORT_DIR, 'admin_panel')
    LOAD_TEST_REPORT = File.join(REPORT_DIR, 'load_test')
    BUILD_TEST_REPORT = File.join(REPORT_DIR, 'build_test')

    # Create directories.
    if create_directories([UNIT_TEST_REPORT, SPEC_TEST_REPORT, ADMIN_TEST_REPORT, BUILD_TEST_REPORT, LOAD_TEST_REPORT, LOG_FILES]) == true
      puts 'Required directories created successfully.'
    else
      puts 'Required directories could not be created. Can not continue...'
    end
  rescue Exception => e
    puts e
    puts e.backtrace
  end

end

def check_and_copy(src_file, dest_file)
  FileUtils.copy(src_file, dest_file) if File.exists?(src_file)
end

#desc "Build .so file for all the test written in c"
task :build_unit_test do
  create_directories([TEST_OBJ_DIR])
  test_files = FileList[File.join(UNIT_TEST_DIR, '*.c'), File.join(HELPER_DIR, '*.c'),
  File.join(YAML_DIR, '*.c')]
  test_obj = {}
  test_files.each do |sfn|
    obj = sfn.sub(/\.[^.]*$/, '.o')
    obj_file = File.join(TEST_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
    test_obj[obj_file]=sfn
  end
  
  webroar_config unless $webroar_config_called
    
  test_obj.each { |obj_file,src_file|
    cmd = "#{CC} #$flags #$debug_flags -c #{src_file} -o #{obj_file}"
    sh cmd
  }
  
  tests_obj_files = FileList[File.join(TEST_OBJ_DIR,"*.o")]
  
  if RUBY_PLATFORM =~ /darwin/
    out_file = File.join(UNIT_TEST_DIR, 'test_ext.dylib')
    cmd = "#{CC} #$lib_flags #{tests_obj_files} -dynamiclib -o #{out_file}"
  else
    out_file = File.join(UNIT_TEST_DIR, 'test_ext.so')
    cmd = "#{CC} #$lib_flags #{tests_obj_files} -shared -o #{out_file}"
  end
  
  sh cmd
end

desc "Build and executes unit test"
task :unit_test => [:create_test_dirs] do
  next unless test_flag == 1
  
  begin
    test_file = File.join(UNIT_TEST_DIR, 'test.log')
    summary_file = File.join(UNIT_TEST_REPORT, 'test-summary')
    File.truncate(test_file, 0) if File.exists?(test_file)

    print "Compiling unit test cases ... "
    system("rake build_unit_test >#{File.join(UNIT_TEST_REPORT,'testcases.log')} 2>>#{File.join(UNIT_TEST_REPORT,'testcases.log')}")
    if($?==0)
      puts "Done."
      system("rake clean >>#{File.join(UNIT_TEST_REPORT,'testcases.log')} 2>>#{File.join(UNIT_TEST_REPORT,'testcases.log')}")
      puts "Running test cases ..."
      puts ""
      $LOAD_PATH.unshift(UNIT_TEST_DIR)
      Dir.chdir(UNIT_TEST_DIR)

      if RUBY_PLATFORM =~ /darwin/
        require 'dl'
        dl = DL::dlopen(File.join(UNIT_TEST_DIR,'test_ext.dylib'))
        run_test = dl.sym("run_test",'0')
        run_test.call()
      else
        require 'test_ext'
        Test::Test.run
      end
      
      puts "\nPlease refer '#{File.join(UNIT_TEST_REPORT, 'test.log')}' for the detailed report."
    else
      puts "Compilation error. Please refer 'testcases.log' for details."
    end
    Dir.chdir(WEBROAR_ROOT)
    next unless File.exists?(test_file)

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
  rescue Exception => e
    Rake::Task[:log_exception].invoke(e)
  end

  check_and_copy(File.join(UNIT_TEST_DIR, 'test.log'), File.join(UNIT_TEST_REPORT, 'test.log'))

end

task :test_setup do
  
  Spec::Rake::SpecTask.new(:spec) do |t|
    t.spec_files = ALL_SPECS
    t.spec_opts << "--format specdoc"
  end
  
  if ENV["debug_build"] == "yes"
    rv = test_setup(true)
  else
    rv = test_setup()
  end
  if rv == -1
    puts " * Some problem occured in test setup. Exiting. * "
    test_flag = 0
    exit(-1)
  end
end

task :spec => :test_setup

desc "Run functional test cases."
task :spec_test => [:create_test_dirs] do
  next unless test_flag == 1
  
  puts "Executing functional tests ..."

  begin
    ENV["SPEC_OPTS"] = "--format specdoc:#{TEST_RESULT}"
    Rake::Task[:spec].invoke()
  rescue Exception => e
    Rake::Task[:log_exception].invoke(e)
  ensure
    if File.exists?(TEST_RESULT)
      system("tail -2 #{File.join(SPEC_DIR,'test.log')} > #{File.join(SPEC_TEST_REPORT,'test_result')}")
      result = File.read(File.join(SPEC_TEST_REPORT,'test_result'))
      total = 0
      failed = 0
      if result =~  /(\d+)\s*(example|examples),\s*(\d+)\s*failure/
        total = $1
        failed = $3
      end
      str = "Functional test summary\nTotal test: #{total}\nFailed test: #{failed}\n"
      File.open(File.join(SPEC_TEST_REPORT,'test-summary'),"w") do |f|
        f.puts str
      end
    end
    
    log_file_pattern = File.join(LOG_FILES,'*.log')
    log_files = Dir.glob(log_file_pattern)
    for file in log_files
      FileUtils.cp(file,File.join(SPEC_TEST_REPORT,"#{File.basename(file)}"))
    end
    
    cmd = "#{File.join(WEBROAR_ROOT,'bin','webroar')} clear"
    system(cmd)    
  end
  
  # copy functional tests related files
  check_and_copy(File.join(SPEC_DIR, 'test.log'), File.join(SPEC_TEST_REPORT, 'test.log'))
  check_and_copy(File.join(SPEC_DIR, 'setup.log'), File.join(SPEC_TEST_REPORT, 'test-setup.log'))
  check_and_copy(File.join(SPEC_DIR, 'test-run.log'), File.join(SPEC_TEST_REPORT, 'test-run.log'))
  
end

desc "Executes Admin-panel test"
task :admin_panel_test => [:create_test_dirs] do
  next unless test_flag == 1

  begin
    puts "Executing Admin-panel tests ..."
    Dir.chdir(File.join(WEBROAR_ROOT,'src','admin_panel'))
    system("rake test RAILS_ENV=test > #{File.join(ADMIN_TEST_REPORT, 'test.log')} 2>#{File.join(ADMIN_TEST_REPORT, 'error.log')}")
    result = File.read(File.join(ADMIN_TEST_REPORT, 'test.log'))
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
    File.open(File.join(ADMIN_TEST_REPORT, 'test-summary'),"w") do |f|
      f.puts str
    end
    Dir.chdir(WEBROAR_ROOT)
  rescue Exception => e
    Rake::Task[:log_exception].invoke(e)
  end
    
  #copy database file
  check_and_copy(File.join(WEBROAR_ROOT, 'src', 'admin_panel', 'db', 'webroar_test.sqlite3'), ADMIN_TEST_REPORT)

end

desc "Load testing by ab tool"
task :load_test => [:create_test_dirs] do
  next unless test_flag == 1

  puts "Executing load tests ..."
  test_setup
  begin
    create_config({},{'baseuri' => '/test_app', 'max_worker' => 6})
    move_config
    create_messaging_config
    move_messaging_config
    start_server
    sleep(15)
    system("ruby #{File.join(TEST_DIR,'load_test.rb')}")
    stop_server
    
    log_file_pattern = File.join(LOG_FILES,'*.log')
    log_files = Dir.glob(log_file_pattern)
    for file in log_files
      FileUtils.cp(file,File.join(LOAD_TEST_REPORT,"#{File.basename(file)}"))
    end
  rescue Exception => e
    Rake::Task[:log_exception].invoke(e)
  ensure
    remove_config
    remove_messaging_config
  end
  
      
  # copy load tests related files
  check_and_copy(File.join(TEST_DIR, 'load_test_summary'), File.join(LOAD_TEST_REPORT, 'test-summary'))
  check_and_copy(File.join(TEST_DIR, 'load_test_result_fix'), File.join(LOAD_TEST_REPORT, 'test-result-fix'))
  check_and_copy(File.join(TEST_DIR, 'load_test_result_random'), File.join(LOAD_TEST_REPORT, 'test-result-random'))
  
end

#desc "Build gem"
task :build_gem => [:create_test_dirs] do
  total += 1
  begin
    file.print "Build gem ... " if file
    cmd = "rm -fr pkg/* 2>> #{File.join(BUILD_TEST_REPORT, 'test.log')}  >>#{File.join(BUILD_TEST_REPORT, 'test.log')}"
    system(cmd)
    Rake::Task[:gem].invoke
    file.puts "Pass" if file
  rescue Exception => e
    failed += 1
    file.puts "Failed" if file
    Rake::Task[:log_exception].invoke(e)
  end
end

#desc "Gem install. It's meant for automated testing, passing predefined values for required inputs"
task :build_install => [:build_gem] do
  total += 1
  gem_file = File.join(WEBROAR_ROOT,'pkg',"webroar-#{Webroar::VERSION::STRING}.gem")
  unless File.exists?(gem_file)
    failed += 1
    next
  end
  
  begin
    file.print "Install gem and server ... " if file
    print "Installing gem ... "
    cmd = "gem install #{gem_file} 2>> #{File.join(BUILD_TEST_REPORT, 'test.log')} >>#{File.join(BUILD_TEST_REPORT, 'test.log')}"
    system(cmd)
    if($?==0)
      puts "Done"
      print "Installing WebROaR ... "
      cmd = "webroar install 2>> #{File.join(BUILD_TEST_REPORT, 'test.log')} >>#{File.join(BUILD_TEST_REPORT, 'test.log')} << **\nadmin\nimpetus\nimpetus\n\n**"
      system(cmd)
      if($?==0)
        file.puts "Pass" if file
        puts "Done"
      else
        failed += 1
        puts "Failed"
        file.puts "Failed" if file
      end
    else
      failed += 1
      puts "Failed"
      file.puts "Failed" if file
    end
  rescue Exception => e
    failed += 1
    puts "Failed"
    file.puts "Failed" if file
    Rake::Task[:log_exception].invoke(e)
  end
end

#desc "Uninstall server and its gem"
task :build_uninstall => [:create_test_dirs] do
  total += 1
  file.print "Uninstall server and gem ... " if file
  begin
    print "Uninstalling WebROaR ... "
    cmd = "webroar uninstall 2>> #{File.join(BUILD_TEST_REPORT, 'test.log')} >>#{File.join(BUILD_TEST_REPORT, 'test.log')}"
    system(cmd)
    if($?==0)
      puts "Done"
    else
      puts "Failed"
    end
    print "Uninstalling gem ..."
    cmd = "gem uninstall webroar -v #{Webroar::VERSION::STRING} -x 2>> #{File.join(BUILD_TEST_REPORT, 'test.log')} >>#{File.join(BUILD_TEST_REPORT, 'test.log')} << **\ny\n** "
    system(cmd)
    if($?==0)
      puts "Done"
      file.puts "Pass" if file
    else
      failed += 1
      puts "Failed"
      file.puts "Failed" if file
    end
  rescue
    failed += 1
    puts "Failed"
    file.puts "Failed" if file
    Rake::Task[:log_exception].invoke(e)
  end
end

#desc "Build test"
task :build_test => [:create_test_dirs] do
  next unless test_flag == 1 or ENV["build_test"] == "yes"
  
  begin
    puts "Executing build tests ..."
    build_test_summary = File.join(BUILD_TEST_REPORT,'test-summary')
    build_test = File.join(BUILD_TEST_REPORT,'build_test')
    File.truncate(File.join(BUILD_TEST_REPORT, 'test.log'), 0) if File.exists?(File.join(BUILD_TEST_REPORT, 'test.log'))
    
    Dir.chdir(WEBROAR_ROOT)
    File.truncate(build_test_summary, 0) if File.exists?(build_test_summary)
    File.truncate(build_test, 0) if File.exist?(build_test)
    
    total = 0
    failed = 0
    file = File.open(build_test,'w')
    
    Rake::Task[:build_install].invoke
    Rake::Task[:build_uninstall].invoke
       
    file.puts "#{total} total, #{failed} failed\n"
    file.close
    
    file = nil
  
    str = "Build test summary\nTotal test: #{total}\nFailed test: #{failed}\n"
    File.open(build_test_summary,"w") do |f|
      f.puts str
    end
  rescue Exception => e
    Rake::Task[:log_exception].invoke(e)
  end
end

def test_cleanup(report_dir)
  
  unless REPORT_DIR == report_dir
    FileUtils.cp_r(REPORT_DIR, report_dir)
  end

end

def test_report
  total = 0
  failed = 0
  f = File.open(File.join(REPORT_DIR,'test-summary'),"w")
  f.puts "------------------------------------------------------------------------------"
  fmt = "%*s%*s%*s"
  str = fmt % [-58,'Type',10,'Total',10,'Failed']
  f.puts str
  f.puts "-------------------------------------------------------------------------------"
  if File.exists?(File.join(UNIT_TEST_REPORT,'test-summary'))
    result = File.read(File.join(UNIT_TEST_REPORT,'test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, 'Unit Tests',10,$1,10,$2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(ADMIN_TEST_REPORT,'test-summary'))
    result = File.read(File.join(ADMIN_TEST_REPORT,'test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)\s*Error:\s*(\d+)/m
    str = fmt % [-58, 'Admin Panel Tests',10,$1,10,$2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(SPEC_TEST_REPORT,'test-summary'))
    result = File.read(File.join(SPEC_TEST_REPORT,'test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, 'Functional Tests', 10, $1, 10, $2]
    f.puts str
    total += $1.to_i
    failed += $2.to_i
  end
  
  if File.exists?(File.join(LOAD_TEST_REPORT,'test-summary'))
    result = File.read(File.join(LOAD_TEST_REPORT,'test-summary'))
    res = result.scan(/Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)\s*/m)
    str = fmt % [-58, "Load Test I - Continuous Run", 10, res[0][0], 10, res[0][1]]
    f.puts str
    str = fmt % [-58, 'Load test II - Random Sleep Intervals', 10, res[1][0], 10, res[1][1]]
    f.puts str
    total += res[0][0].to_i + res[1][0].to_i
    failed += res[0][1].to_i + res[1][1].to_i
  end
  
  if File.exists?(File.join(BUILD_TEST_REPORT,'test-summary'))
    result = File.read(File.join(BUILD_TEST_REPORT,'test-summary'))
    result =~ /Total\s*test:\s*(\d+)\s*Failed\s*test:\s*(\d+)/m
    str = fmt % [-58, "Build Tests", 10, $1, 10, $2]
    f.puts str
    f.puts "\n"
    total += $1.to_i
    failed += $2.to_i
  end
  f.close
  
  f = File.open(File.join(REPORT_DIR,'test-report'),"w")
  f.puts File.read(File.join(REPORT_DIR,'test-summary')) if File.exists?(File.join(REPORT_DIR,'test-summary'))
  
  if File.exists?(File.join(UNIT_TEST_REPORT,'test.log'))
    f.puts "-------------------------------Unit Tests Result--------------------------------"
    f.puts File.read(File.join(UNIT_TEST_REPORT,'test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(ADMIN_TEST_REPORT,'test.log'))
    f.puts "-----------------------------Admin Panel Tests Result---------------------------"
    f.puts File.read(File.join(ADMIN_TEST_REPORT, 'test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(SPEC_TEST_REPORT,'test.log'))
    f.puts "------------------------------Functional Tests Result---------------------------"
    f.puts File.read(File.join(SPEC_TEST_REPORT,'test.log'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(LOAD_TEST_REPORT,'test-result-fix'))
    f.puts "---------------------------Load Test I - Continuous Run-------------------------"
    f.puts File.read(File.join(LOAD_TEST_REPORT,'test-result-fix'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(LOAD_TEST_REPORT,'test-result-random'))
    f.puts "------------------------Load test II - Random Sleep Intervals-------------------"
    f.puts File.read(File.join(LOAD_TEST_REPORT,'test-result-random'))
    f.puts "\n"
  end
  
  if File.exists?(File.join(BUILD_TEST_REPORT,'build_test'))
    f.puts "--------------------------------Build Tests Result------------------------------"
    f.puts File.read(File.join(BUILD_TEST_REPORT,'build_test'))
    f.puts "\n"
  end
  
  f.close
  
  f = File.open(File.join(REPORT_DIR,"test-result"),"w")
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

desc "Integrated testing executes unit tests, admin-panel tests and functional\
 tests. To run load tests give load_test=yes, to run build tests give build_test\
=yes as an argument. To run test under debug build give debug_build=yes as an\
 argument."
task :all_test => [:create_test_dirs, :unit_test, :spec_test, :admin_panel_test, :load_test] do

  unless ENV["no_report"]
    test_report
  end
  
  if(ENV["report_dir"])
    test_cleanup(ENV["report_dir"])
  end  

end

desc "Runs integrated test-suit comprises of gem creation, installation, unit \
tests, admin-panel tests, functional tests. To run load tests give load_test=\
yes as an argument. To run under debug build give debug_build=yes as an \
argument."
task :test => [:build_test] do
  
  Dir.chdir(WEBROAR_ROOT)

  Rake::Task[:build_install].reenable
  Rake::Task[:build_install].invoke
  
  str = " "
  str += "-d " if ENV["debug_build"] == "yes"
  str += "-l" if ENV["load_test"] == "yes"
  
  # Run tests on installed directory. Copy test-report and test-summary to TEST_DIR
  cmd = "webroar test -r=#{REPORT_DIR} #{str}"
  system(cmd)
  Rake::Task[:build_uninstall].reenable
  Rake::Task[:build_uninstall].invoke
end
