# frozen_string_literal: true

class AddTool < ApplicationTool
  description 'Add two numbers the way only MCP can'

  arguments do
    required(:a).filled(:integer).description('First number to add')
    required(:b).filled(:integer).description('Second number to add')
  end

  def call(a:, b:)
    {
      content: [
        {
          type: "text",
          text: (a + b).to_s
        }
      ]
    }
  end
end