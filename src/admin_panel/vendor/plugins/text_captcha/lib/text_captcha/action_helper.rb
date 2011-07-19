module TextCaptcha
  module ActionHelper
    def rand_question
      question = "What is "
      operands = [rand(10),rand(10)]
      operators = ['+','-','*']
      operator = operators.choice
      case operator
      when '+'
        result = operands.max + operands.min
      when '-'
        result = operands.max - operands.min
      when '*'
        result = operands.max * operands.min
      end

      question << " #{operands.max} #{operator} #{operands.min} = "
      return question,result
    end
  end
end
