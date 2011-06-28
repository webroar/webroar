# Captcha
PLUGIN_ROOT = File.join(::Rails.root,"vendor","plugins","captcha")
CAPTCHA_IMAGE_PATH = File.join(PLUGIN_ROOT,"public","images")
APP_IMAGE_PATH = File.join(::Rails.root,"public","images")
require 'captcha/action_helper'
Captcha::ActionHelper.copy_refresh_image
require 'captcha/action_controller'
require 'captcha/action_view'