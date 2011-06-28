ActionController::Routing::Routes.draw do |map|
  map.change_captcha('/change_captcha', {:action=>'change_capthca',:controller=>'captcha_controller'})
end
