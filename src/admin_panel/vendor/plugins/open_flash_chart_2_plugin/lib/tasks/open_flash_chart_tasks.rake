namespace :open_flash_chart_2 do
  PLUGIN_ROOT = File.dirname(__FILE__) + '/../../'

  desc 'Installs required swf in public/ and javascript files to the public/javascripts directory.'
  task :install do
    FileUtils.cp "#{PLUGIN_ROOT}requirements/open-flash-chart.swf", "#{::Rails.root.to_s}/public/", :verbose => true
    FileUtils.cp "#{PLUGIN_ROOT}requirements/swfobject.js", "#{::Rails.root.to_s}/public/javascripts/", :verbose => true
  end

  desc 'Removes the swf and javascripts for the plugin.'
  task :uninstall do
    FileUtils.rm "#{::Rails.root.to_s}/public/javascripts/swfobject.js", :force => true, :verbose => true
    FileUtils.rm "#{::Rails.root.to_s}/public/open-flash-chart.swf", :force => true, :verbose => true
  end

  desc 'Removes the old swf and javascripts for the plugin and copy new one to public direcory.'
  task :reinstall do
    FileUtils.rm "#{::Rails.root.to_s}/public/javascripts/swfobject.js", :force => true, :verbose => true
    FileUtils.rm "#{::Rails.root.to_s}/public/open-flash-chart.swf", :force => true, :verbose => true

    FileUtils.cp "#{PLUGIN_ROOT}requirements/open-flash-chart.swf", "#{::Rails.root.to_s}/public/", :verbose => true
    FileUtils.cp "#{PLUGIN_ROOT}requirements/swfobject.js", "#{::Rails.root.to_s}/public/javascripts/", :verbose => true
  end
end