puts "Removing files from public directory:"
FileUtils.rm "#{Rails.root}/public/javascripts/swfobject.js"
FileUtils.rm "#{Rails.root}/public/open-flash-chart.swf"
puts "Plugin uninstalled."
