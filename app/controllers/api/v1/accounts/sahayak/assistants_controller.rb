# frozen_string_literal: true

class Api::V1::Accounts::Sahayak::AssistantsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :set_conversation, only: [:generate_suggestions, :answer_product_query]

  def generate_suggestions
    service = Ai::AssistantService.new(account: @current_account, conversation: @conversation)
    suggestions = service.suggest_replies
    render json: { suggestions: suggestions }
  end

  def answer_product_query
    message_content = params[:content]
    service = Ai::AssistantService.new(account: @current_account, conversation: @conversation)
    answer = service.answer_product_query(message_content)
    render json: { answer: answer }
  end

  private

  def set_conversation
    @conversation = @current_account.conversations.find_by(display_id: params[:id])
  end
end
