require 'digest'
module TextCaptcha
  module ActionController
    include ActionHelper
    def create_question_captcha
      @question,@answer = rand_question
      @answer = Digest::SHA2.hexdigest(@answer.to_s)
    end

    def validate_captcha_answer
      create_question_captcha
      if captcha_failure?
        set_captcha_failure_message
        return false
      end
      return true
    end

    def captcha_failure?
      params[:_][:_] != Digest::SHA2.hexdigest(params[:textCaptcha][:answer])
    end

    def set_captcha_failure_message
      if params[:textCaptcha][:answer].strip == ""
        flash[:notice] = "<span style='color:red;'>Varification code can't be blank!</span>"
      else
        flash[:notice] = "<span style='color:red;'>Wrong Answer, Please enter correct answer!</span>"
      end
    end
  end
end

ActionController::Base.class_eval { include TextCaptcha::ActionController }
