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
#        Rake file to compile source code
###############################################################################

#rake without any argument, it will invoke default task of making executable.
#rake::clean, removes all the object files from obj directory.
#rake::clobber, performs rake::clean, also removes executable from bin directory.

require 'mkmf'

CC = CONFIG['CC']
ROOT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
LIBEV_DIR = File.join(ROOT_DIR, 'src', 'vendor', 'libev').freeze
EBB_DIR = File.join(ROOT_DIR, 'src', 'vendor', 'libebb').freeze
YAML_DIR = File.join(ROOT_DIR, 'src', 'vendor', 'libyaml').freeze
BIN_DIR = File.join(ROOT_DIR,'bin').freeze
HEAD_DIR = File.join(ROOT_DIR, 'src', 'head').freeze
HELPER_DIR = File.join(ROOT_DIR, 'src', 'helper').freeze
WORKER_DIR = File.join(ROOT_DIR, 'src', 'worker').freeze
CONF_DIR = File.join(ROOT_DIR, 'conf').freeze
UNIT_TEST_DIR = File.join(ROOT_DIR, 'test', 'unit').freeze
HEAD_OBJ_DIR = File.join(ROOT_DIR, 'obj', 'head').freeze
HELPER_OBJ_DIR = File.join(ROOT_DIR, 'obj', 'helper').freeze
WORKER_OBJ_DIR = File.join(ROOT_DIR, 'obj', 'worker').freeze
TEST_OBJ_DIR = File.join(ROOT_DIR, 'obj', 'test').freeze
LOG_FILES = File.join('','var','log','webroar').freeze
TMP_FILES = File.join('','tmp').freeze
RUBY_VERSION_CODE = RUBY_VERSION.gsub(/\D/, '').freeze

#Boolean to keep check method webroar_config has been called or not
$webroar_config_called = false

## Set compilation flags needed by libebb & libev. Courtesy libebb
$flags = ""

## Set library flags needed
$lib_flags = ""

CLEAN.include(File.join(WORKER_OBJ_DIR,'*.o'), File.join(HEAD_OBJ_DIR,'*.o'), File.join(HELPER_OBJ_DIR,'*.o'), File.join(TEST_OBJ_DIR,'*.o'))
CLOBBER.include(File.join(BIN_DIR,'webroar-head'),File.join(BIN_DIR,'webroar-worker'), File.join(UNIT_TEST_DIR,'*.so'))

def set_flags
  flags = []
  flags << '-DEV_USE_SELECT' if have_header('sys/select.h')
  flags << '-DEV_USE_POLL' if have_header('poll.h')
  flags << '-DEV_USE_EPOLL' if have_header('sys/epoll.h')
  flags << '-DEV_USE_KQUEUE' if have_header('sys/event.h') and have_header('sys/queue.h')
  flags << '-DEV_USE_PORT' if have_header('port.h')
  flags << '-DEV_USE_INOTIFY' if have_header('sys/inotify.h')
  flags << '-DEV_USE_MONOTONIC=0'
  flags << '-DHAVE_GNUTLS' if ENV['ssl'].eql?("yes")
  flags << "-DRUBY_VERSION=#{RUBY_VERSION_CODE}"
  flags << Config::expand($CFLAGS,CONFIG)
  flags << "-g -O2" if RUBY_PLATFORM =~ /darwin/
  flags << "-DL_ERROR -DL_INFO"
  $flags << flags.join(" ")
end

def set_include_flags
  inc_flags = [" "]
  inc_flags << " #{ENV['include_flags']}" if ENV['include_flags']
  
  if RUBY_VERSION_CODE.to_i < 190
    inc_flags << Config::expand($INCFLAGS,CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote))
  else
    inc_flags << Config::expand($INCFLAGS,CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote, 'arch_hdrdir' => "#$arch_hdrdir", 'top_srcdir' => $top_srcdir.quote))
  end
  
  inc_flags << " #{Config::CONFIG['cppflags']}" if Config::CONFIG['cppflags']
  
  include_dir = ["#{LIBEV_DIR}","#{EBB_DIR}","#{HEAD_DIR}","#{YAML_DIR}","#{HELPER_DIR}","#{UNIT_TEST_DIR}", "#{WORKER_DIR}"]
  include_dir << Config::CONFIG['includedir'] if Config::CONFIG['includedir']
  
  include_dir.each do |dir|
    inc_flags << " -I#{dir} "
  end
  $flags << inc_flags.join(" ")
end

def set_lib_flags
  lib_flags = [$libs, $LIBS]
  lib_flags << " #{ENV['library_flags']}" if ENV['library_flags']
  lib_flags <<  "-L" + Config::expand($libdir,CONFIG)
  lib_flags << " "
  $lib_flags << lib_flags.join(" ")
end

def webroar_config
  set_flags
  set_include_flags
  set_lib_flags
  $webroar_config_called = true
end

head_bin = File.join(BIN_DIR,"webroar-head")
worker_bin = File.join(BIN_DIR,"webroar-worker")

head_files = FileList[File.join(HEAD_DIR,'*.c'),File.join(EBB_DIR,'*.c')]
worker_files = FileList[File.join(WORKER_DIR,'*.c')]
helper_files = FileList[File.join(HELPER_DIR,'*.c'), File.join(YAML_DIR,'*.c')]

#src_obj is a hash which will keep object file name as key and source file name as value. This is used to map source file to object file.
#It's been used at time of object generation
head_obj={}
worker_obj={}
helper_obj={}

# File dependencies go here ...
head_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(HEAD_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  
  desc "Setting Executable's dependency on objects files"
  file head_bin => obj_file
  
  #Insertion of object file to source file mapping in hash
  head_obj[obj_file]=sfn
end

head_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    webroar_config unless $webroar_config_called
    cmd = "#{CC}  #{$flags} -c #{src_file} -o #{obj_file} "
    sh cmd
  end
}

worker_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(WORKER_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  
  # "Setting Executable's dependency on objects files"
  file worker_bin => obj_file
  
  # "Setting object file dependency on source file"
  #Insertion of object file to source file mapping in hash
  worker_obj[obj_file]=sfn
end

worker_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    webroar_config unless $webroar_config_called
    flags = $flags
    flags << ' -DW_ZLIB' if ENV['zlib']=='yes'
    flags << ' -DW_REGEX' if ENV['regex']=='yes'
    cmd = "#{CC} #{flags} -c  #{src_file} -o #{obj_file} "
    sh cmd
  end
}

helper_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(HELPER_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  
  desc "Setting Executable's dependency on objects files"
  #file worker_bin => obj_file
  file head_bin => obj_file
  
  #Insertion of object file to source file mapping in hash
  helper_obj[obj_file]=sfn
end

helper_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    webroar_config unless $webroar_config_called
    cmd = "#{CC} #{$flags} -c #{src_file} -o #{obj_file} "
    sh cmd
  end
}

file worker_bin do
  puts $lib_flags
  lib_flags = String.new($lib_flags)
  lib_flags << Config::expand($LIBRUBYARG_SHARED,CONFIG) if CONFIG["ENABLE_SHARED"] == "yes"
  lib_flags << Config::expand($LIBRUBYARG_STATIC, CONFIG) if CONFIG["ENABLE_SHARED"] == "no"
  lib_flags << " -lz" if ENV['zlib'] == "yes"
  #libraries for making executable
  out_file = File.join(BIN_DIR,'webroar-worker')
  object_files = FileList[File.join(WORKER_OBJ_DIR,'*.o'), File.join(HELPER_OBJ_DIR,'*.o')]
  # -rdynamic option to get function name in stacktrace
  cmd = "#{CC} -o #{out_file} #{object_files} -rdynamic #{lib_flags}"
  sh cmd
end

file head_bin do
  puts $lib_flags
  out_file = File.join(BIN_DIR,'webroar-head')
  object_files = FileList[File.join(HEAD_OBJ_DIR,'*.o'), File.join(HELPER_OBJ_DIR,'*.o')]
  # -rdynamic option to get function name in stacktrace
  cmd="#{CC} -o #{out_file} #{object_files} -rdynamic #{$lib_flags} #{ENV['ssl'].eql?("yes")? ' -lgnutls ' : '' } "
  sh cmd
end

file head_bin => worker_bin
task :compile => [:create_obj_dirs, head_bin]
task :default => :compile

desc "Build with debug statements"
task :debug_build do
  $flags << " -DL_DEBUG "
  d=Rake::Task[:default]
  d.invoke();
end

desc "Creates required folders for compilation."
task :create_obj_dirs do
  if create_directories([WORKER_OBJ_DIR, HEAD_OBJ_DIR, HELPER_OBJ_DIR, TMP_FILES]) == true
    puts 'Required directories created successfully. Building executables...'
  else
    puts 'Required directories could not be created. Can not continue...'
  end
end

task :create_install_dirs do
  if create_directories([LOG_FILES]) == true
    puts 'Required directories created successfully. Building executables...'
  else
    puts 'Required directories could not be created. Can not continue...'
  end
end

#Create directories if they don't exists
def create_directories(required_directories)
  rv = true
  for directory in required_directories
    #check to see if it exists
    unless File.exists?(directory)
      begin
        print "#{directory} doesn't exist. Creating it..."
        FileUtils.mkdir_p(directory)
      rescue Exception => e
        puts "Failed."
        puts e
        puts e.backtrace
        rv = false
        next
      end
      puts "Created."
    end
  end
  rv
end
