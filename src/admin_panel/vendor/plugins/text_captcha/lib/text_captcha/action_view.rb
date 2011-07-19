module TextCaptcha
  module ActionView

    def text_captcha_tag
      block = "<div id='captcha_div'>Prove you are a human : #{@question}"
      block = block + "#{get_hidden_field}"
      block = block + get_captcha_text_field + "</div>" 
    end
  private
    def get_hidden_field
      "#{hidden_field '_' ,'_',:value => "#{@answer}" }"
    end

    def get_captcha_text_field
      "#{text_field 'textCaptcha' ,'answer',:style => 'width:50px'}"
    end

  end
end

ActionView::Base.class_eval { include TextCaptcha::ActionView }