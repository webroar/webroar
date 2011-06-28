module Captcha
  module ActionView

    def image_captcha_tag
      block = "<div id='captcha_div' style='height:50px;width:240px;'>#{get_captcha_image}#{get_change_captcha_image_link}#{get_hidden_field}</div>"
      block = block + get_captcha_text_field + "<br>" + get_case_related_message
    end

    def get_captcha_image
      img = "captcha_output.jpg?#{@image_asset_id}"
      "#{image_tag img,:size => '150x40',:alt => 'Loagin image..'}&nbsp;"
    end

    def get_hidden_field
      "#{hidden_field '_' ,'_',:value => "#{@secret}" }"
    end

    def get_change_captcha_image_link
      "#{link_to_remote image_tag('refresh.png',:border =>0,:alt => "Refresh", :size => '35x35',:title => "Refresh"),:update => 'captcha_div',:url => { :action => :change_captcha,:controller => :captcha }}"
    end

    def get_captcha_text_field
      "#{text_field 'captcha' ,'text',:style => "width:150px;" }"
    end

    def get_case_related_message(type = "sensitive")
      "<h6 style='margin:0px;'>Letters are case-#{type}</h6>"
    end
  end
end

ActionView::Base.class_eval { include Captcha::ActionView }
