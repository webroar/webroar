require 'digest'
module Captcha
  module ActionController
    include ActionHelper
    def create_captcha
      @secret = Digest::SHA2.hexdigest(create_image_with_text(6))
      @image_asset_id = File.mtime("#{APP_IMAGE_PATH}/captcha_output.jpg").to_i.to_s
    end

    def validate_captcha
      if captcha_failure?
        create_captcha
        set_captcha_failure_message
        return false
      end
      return true
    end

    def captcha_failure?
      params[:_][:_] != Digest::SHA2.hexdigest(params[:captcha][:text])
    end

    def set_captcha_failure_message
      if params[:captcha][:text].strip == ""
        flash[:notice] = "<span style='color:red;'>Varification code can't be blank!</span>"
      else
        flash[:notice] = "<span style='color:red;'>Please enter valid varification code!</span>"
      end
    end
  end
end

ActionController::Base.class_eval { include Captcha::ActionController }
