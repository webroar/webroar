puts "Copying files to public directory:"
PLUGIN_ROOT = File.dirname(__FILE__) + '/'
FileUtils.cp "#{PLUGIN_ROOT}requirements/*.swf", "#{Rails.root}/public", :verbose => true
FileUtils.cp "#{PLUGIN_ROOT}requirements/*.js", "#{Rails.root}/public/javascripts", :verbose => true
puts "Plugin installed."
puts "Please read README file."