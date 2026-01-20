# frozen_string_literal: true

class Ai::AssistantService
  pattr_initialize [:account!, :conversation!]

  def suggest_replies
    return [] unless account.sahayak_assistant_enabled?
    
    context = build_conversation_context
    prompt = build_suggestion_prompt(context)
    
    response = call_groq_api(prompt)
    return [] if response[:error]
    
    parse_suggestions(response[:message])
  end

  def answer_product_query(message_content)
    # Search for products in inventory
    products = account.products.all
    product_context = products.map { |p| "#{p.name}: #{p.description} (Price: #{p.cost} #{p.currency})" }.join("\n")
    
    prompt = <<~PROMPT
      You are a helpful assistant for a store. Using the following product inventory, answer the user's question.
      If the product is not in the inventory, politely inform them.
      
      Inventory:
      #{product_context}
      
      User Question: #{message_content}
      
      Provide a helpful, concise response.
    PROMPT
    
    response = call_groq_api(prompt)
    response[:message]
  end

  private

  def build_conversation_context
    conversation.messages.chat.last(10).map do |m|
      "#{m.sender_type}: #{m.content}"
    end.join("\n")
  end

  def build_suggestion_prompt(context)
    <<~PROMPT
      Based on the following conversation history, suggest 3 short, helpful response snippets (max 10 words each) for the agent to use.
      
      Conversation:
      #{context}
      
      Respond only with a JSON array of strings: ["Snippet 1", "Snippet 2", "Snippet 3"]
    PROMPT
  end

  def call_groq_api(prompt)
    # Reuse logic from AutoLabelService or centralize it
    # For now, implementing a simplified version using RubyLLM
    Llm::Config.initialize!
    
    ai_config = account.ai_configs.find_by(provider: 'groq')
    api_key = ai_config&.api_key || InstallationConfig.find_by(name: 'GROQ_API_KEY')&.value
    api_base = ai_config&.api_endpoint || Llm::Config.groq_endpoint
    
    return { error: 'Groq not configured' } if api_key.blank?
    
    Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
       result = RubyLLM::Chat.create(
         model: ai_config&.ai_model_name || 'llama-3.1-70b-versatile',
         messages: [{ role: 'user', content: prompt }],
         temperature: 0.7,
         context: context
       )
       { message: result.dig('choices', 0, 'message', 'content') }
    rescue StandardError => e
       { error: e.message }
    end
  end

  def parse_suggestions(ai_message)
    json_match = ai_message.match(/\[.*\]/m)
    return [] unless json_match
    
    JSON.parse(json_match[0])
  rescue JSON::ParserError
    []
  end
end
