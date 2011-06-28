class CaptchaController < ActionController::Base
  before_filter :create_captcha, :only => :change_captcha
  def change_captcha
    render :partial => "change_captcha"
  end
end