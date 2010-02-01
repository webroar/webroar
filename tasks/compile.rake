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

#% $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib")

require 'mkmf'

#Boolean to keep check method webroar_config has been called or not
$webroar_config_called=false

## Set compilation flags needed by libebb & libev. Courtesy libebb
$flags = []

def webroar_config
  #add flag to compile libev
  
  if have_header('sys/select.h')
    $flags << '-DEV_USE_SELECT'
  end
  
  if have_header('poll.h')
    $flags << '-DEV_USE_POLL'
  end
  
  if have_header('sys/epoll.h')
    $flags << '-DEV_USE_EPOLL'
  end
  
  if have_header('sys/event.h') and have_header('sys/queue.h')
    $flags << '-DEV_USE_KQUEUE'
  end
  
  if have_header('port.h')
    $flags << '-DEV_USE_PORT'
  end
  
  if have_header('sys/inotify.h')
    $flags << '-DEV_USE_INOTIFY'
  end
  
  $flags << '-DEV_USE_MONOTONIC=0'
  if ENV['ssl'].eql?("yes")
    puts "Adding HAVE_GNUTLS flag."
    $flags << '-DHAVE_GNUTLS'
  end
  $flags = $flags.join(" ")
  $webroar_config_called=true
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

ruby_version_code = RUBY_VERSION.gsub(/\D/, '')
$flags << "-DRUBY_VERSION=#{ruby_version_code}"
## Include for ruby files
if ruby_version_code.to_i < 190
  $inc_flags = Config::expand($INCFLAGS,CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote))
else
  $inc_flags = Config::expand($INCFLAGS,CONFIG.merge('hdrdir' => $hdrdir.quote, 'srcdir' => $srcdir.quote, 'arch_hdrdir' => "#$arch_hdrdir", 'top_srcdir' => $top_srcdir.quote))
end

$inc_flags << " #{Config::CONFIG['cppflags']}" if Config::CONFIG['cppflags']

$c_flags = Config::expand($CFLAGS,CONFIG)
if RUBY_PLATFORM =~ /darwin/
  $c_flags += " -g -O2 "
end
$debug_flags = " -DL_ERROR -DL_INFO "

## Set static veriables

COMPILER = CONFIG['CC']
DIR = File.expand_path(File.join(File.dirname(__FILE__), '..')).freeze
SRC_DIR = File.join(DIR, 'src').freeze
HEAD_DIR = File.join(SRC_DIR, 'head').freeze
HELPER_DIR = File.join(SRC_DIR, 'helper').freeze
VENDOR_DIR = File.join(SRC_DIR, 'vendor').freeze
LIBEV_DIR = File.join(VENDOR_DIR, 'libev').freeze
EBB_DIR = File.join(VENDOR_DIR, 'libebb').freeze
BIN_DIR = File.join(DIR,'bin').freeze
OBJ_DIR = File.join(DIR,'obj').freeze
WORKER_DIR = File.join(SRC_DIR, 'worker').freeze
WORKER_OBJ_DIR = File.join(OBJ_DIR, 'worker').freeze
YAML_DIR = File.join(VENDOR_DIR, 'libyaml').freeze
YAML_OBJ_DIR = File.join(OBJ_DIR, 'libyaml').freeze
CONF_DIR = File.join(SRC_DIR, 'conf').freeze
UNIT_TEST_DIR = File.join(DIR, 'test', 'unit').freeze
TEST_OBJ_DIR = File.join(OBJ_DIR, 'test').freeze
LOG_FILES = File.join('','var','log','webroar').freeze
TMP_FILES = File.join('','tmp').freeze

## Create necessory directories
#create_directories([OBJ_DIR, WORKER_OBJ_DIR, YAML_OBJ_DIR, TEST_OBJ_DIR, TMP_FILES, LOG_FILES])

include_dir = ["#{LIBEV_DIR}","#{EBB_DIR}","#{HEAD_DIR}","#{YAML_DIR}","#{HELPER_DIR}","#{UNIT_TEST_DIR}", "#{WORKER_DIR}"]

include_dir.each do |dir|
  $inc_flags << " -I#{dir} "
end

$inc_flags << " #{ENV['include_flags']}" if ENV['include_flags']

CLEAN.include(File.join(OBJ_DIR,'*.o'),File.join(WORKER_OBJ_DIR,'*.o'), File.join(YAML_OBJ_DIR,'*.o'), File.join(TEST_OBJ_DIR,'*.o'))
CLOBBER.include(File.join(BIN_DIR,'webroar-head'),File.join(BIN_DIR,'webroar-worker'), File.join(UNIT_TEST_DIR,'*.so'))

webroar_bin = File.join(BIN_DIR,"webroar-head")
worker_bin = File.join(BIN_DIR,"webroar-worker")

#% ebb_request_parser_rl_file = FileList[File.join(EBB_DIR,'ebb_requset_parser.rl')]
src_files = FileList[File.join(HEAD_DIR,'*.c'),File.join(EBB_DIR,'*.c')]
worker_files = FileList[File.join(WORKER_DIR,'*.c')]
yaml_files = FileList[File.join(YAML_DIR,'*.c')]
helper_files = FileList[File.join(HELPER_DIR,'*.c')]

#src_obj is a hash which will keep object file name as key and source file name as value. This is used to map source file to object file.
#It's been used at time of object generation
src_obj={}
worker_obj={}
yaml_obj={}
helper_obj={}

# File dependencies go here ...
src_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  
  desc "Setting Executable's dependency on objects files"
  file webroar_bin => obj_file
  
  #Insertion of object file to source file mapping in hash
  src_obj[obj_file]=sfn
end

src_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    unless $webroar_config_called
      webroar_config
    end
    cmd = "#{COMPILER}  #$inc_flags #$c_flags #$flags #$debug_flags -c #{src_file} -o #{obj_file} "
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
    unless $webroar_config_called
      webroar_config
    end
    cmd = "#{COMPILER} #$inc_flags #$c_flags #$flags #$debug_flags -c  #{src_file} -o #{obj_file} "
    sh cmd
  end
}

yaml_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(YAML_OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  file webroar_bin => obj_file
  yaml_obj[obj_file]=sfn
end

yaml_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    cmd = "#{COMPILER}  #$inc_flags -c #{src_file} -o #{obj_file} "
    sh cmd
  end
}

helper_files.each do |sfn|
  obj = sfn.sub(/\.[^.]*$/, '.o')
  obj_file = File.join(OBJ_DIR , obj[obj.rindex(File::SEPARATOR)+1..obj.length])
  
  desc "Setting Executable's dependency on objects files"
  file worker_bin => obj_file
  
  #Insertion of object file to source file mapping in hash
  helper_obj[obj_file]=sfn
end

helper_obj.each { |obj_file,src_file|
  file obj_file => src_file do
    unless $webroar_config_called
      webroar_config
    end
    cmd = "#{COMPILER}  #$inc_flags #$c_flags #$flags #$debug_flags -c #{src_file} -o #{obj_file} "
    sh cmd
  end
}

file worker_bin do
  unless $webroar_config_called
    webroar_config
  end
  #libraries for making executable
  lib_flags = $libs + $LIBS + ' -L' + Config::expand($libdir,CONFIG)  + ' ' + Config::expand($LIBRUBYARG_SHARED,CONFIG)
  #$libs += ' '+CONFIG["LIBRUBYARG"]  
  #$libs += ' -lpthread '
  lib_flags += " #{ENV['library_flags']}" if ENV['library_flags']
  out_file=File.join(BIN_DIR,'webroar-worker')
  object_files=FileList[File.join(WORKER_OBJ_DIR,'*.o'), helper_obj.keys, File.join(YAML_OBJ_DIR,'*.o')]
  # -rdynamic option to get function name in stacktrace
  cmd="#{COMPILER} #{lib_flags} -rdynamic #{object_files} -o #{out_file}"
  sh cmd
end

file webroar_bin do
  unless $webroar_config_called
    webroar_config
  end
  #libraries for making executable
  lib_flags = $libs + $LIBS # + ' -L' + Config::expand($libdir,CONFIG)  + ' ' + Config::expand($LIBRUBYARG_SHARED,CONFIG)
  #$libs += ' '+CONFIG["LIBRUBYARG"]  
  #$libs += ' -lpthread '
  lib_flags += " #{ENV['library_flags']}" if ENV['library_flags']
  if ENV['ssl'].eql?("yes")
    puts "Compiling with gnutls library."
    lib_flags += ' -L' + Config::CONFIG['libdir'] + ' -lgnutls '
  end
  out_file=File.join(BIN_DIR,'webroar-head')
  object_files=FileList[File.join(OBJ_DIR,'*.o'),File.join(YAML_OBJ_DIR,'*.o')]
  # -rdynamic option to get function name in stacktrace
  cmd="#{COMPILER} #{lib_flags} -rdynamic #{object_files} -o #{out_file}"
  sh cmd
end

file webroar_bin => worker_bin
task :compile => [:create_obj_dirs, webroar_bin]
task :default => :compile

desc "Build with debug statements"
task :debug_build do
  $debug_flags<<" -DL_DEBUG "
  d=Rake::Task[:default]
  d.invoke();
end

$sbin_flag=true

desc "Creates required folders for compilation."
task :create_obj_dirs do
  if create_directories([OBJ_DIR, WORKER_OBJ_DIR, YAML_OBJ_DIR, TMP_FILES]) == true
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
