begin
  gem 'mini_magick'
  require 'mini_magick'
rescue Exception => e
  puts "Could not find RubyGem mini_magick (>= 0),Please use 'gem install mini_magick' for the installation of mini_magick" 
  exit
end

module Captcha
  module ActionHelper

    def rand_str(len=6)
      alphabets = [('a'..'z').to_a, ('A'..'Z').to_a].flatten!
      alphanumerics = [('a'..'z').to_a,('A'..'Z').to_a,('0'..'9').to_a].flatten!
      str = alphabets[rand(alphabets.size)]
      ( len - 1 ).times do
        str << alphanumerics[rand(alphanumerics.size)]
      end
      str
    end

    def get_random_image
      MiniMagick::Image.open("#{CAPTCHA_IMAGE_PATH}/captcha_#{rand(12)}.jpg")
    end

    def create_image_with_text(len)
      img = get_random_image
      text = rand_str(len)
      img.combine_options do |c|
        c.resize "150x40"
        c.gravity 'Center'
        c.fill("#FFFFFF")
        c.draw "text 0,2 #{text}"
        c.font 'Times New Roman'
        c.pointsize '30'
      end
      img.write("#{APP_IMAGE_PATH}/captcha_output.jpg")
      text
    end

    def ActionHelper.copy_refresh_image
      unless File.file?("#{APP_IMAGE_PATH}/refresh.png")
        FileUtils.cp "#{CAPTCHA_IMAGE_PATH}/refresh.png","#{APP_IMAGE_PATH}/refresh.png"
      end
    end
  end
end
