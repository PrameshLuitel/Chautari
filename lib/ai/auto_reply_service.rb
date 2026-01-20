# frozen_string_literal: true

module Ai
  class AutoReplyService
    pattr_initialize [:message!, :conversation!]

    # Message type classifications
    MESSAGE_TYPES = {
      greeting: { auto_approve: true, priority: 'high' },
      product_inquiry: { auto_approve: true, priority: 'high' },
      support: { auto_approve: false, priority: 'medium' },
      complaint: { auto_approve: false, priority: 'high' },
      other: { auto_approve: false, priority: 'low' }
    }.freeze

    def perform
      return { success: false, error: 'AI not configured' } unless ai_config
      return { success: false, error: 'Auto-reply not enabled' } unless auto_reply_enabled?
      return { success: false, error: 'Not an incoming message' } unless message.incoming?

      # Classify the message
      classification = classify_message

      # Generate reply
      reply_content = generate_reply(classification)

      return { success: false, error: reply_content[:error] } if reply_content[:error]

      # Determine if auto-approve
      should_auto_approve = should_auto_approve?(classification[:type])

      # Create the reply
      if should_auto_approve
        send_reply(reply_content[:content])
        {
          success: true,
          type: classification[:type],
          auto_approved: true,
          content: reply_content[:content],
          confidence: classification[:confidence]
        }
      else
        queue_for_approval(reply_content[:content], classification)
        {
          success: true,
          type: classification[:type],
          auto_approved: false,
          queued: true,
          content: reply_content[:content],
          confidence: classification[:confidence]
        }
      end
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      { success: false, error: e.message }
    end

    private

    def account
      @account ||= conversation.account
    end

    def ai_config
      @ai_config ||= account.ai_configs.find_by(provider: 'groq', status: 'active')
    end

    def auto_reply_enabled?
      ai_config&.features_enabled&.include?('auto_reply')
    end

    def classify_message
      prompt = build_classification_prompt

      response = call_groq_api(prompt, max_tokens: 100, temperature: 0.1)

      return fallback_classification if response[:error]

      parse_classification(response[:message])
    end

    def build_classification_prompt
      <<~PROMPT
        Classify this customer message into ONE category:

        Categories:
        - greeting: Hello, hi, good morning, how are you, etc.
        - product_inquiry: Questions about products, inventory, availability, features
        - support: Technical issues, help requests, how-to questions
        - complaint: Problems, dissatisfaction, negative feedback
        - other: Everything else

        Message: "#{message.content}"

        Previous context (last 3 messages):
        #{get_conversation_context}

        Respond ONLY with JSON:
        {
          "type": "greeting",
          "confidence": 95,
          "reason": "Brief explanation"
        }
      PROMPT
    end

    def get_conversation_context
      conversation.messages
                  .where.not(id: message.id)
                  .order(created_at: :desc)
                  .limit(3)
                  .reverse
                  .map { |m| "#{m.sender_type}: #{m.content&.truncate(100)}" }
                  .join("\n")
    end

    def generate_reply(classification)
      prompt = build_reply_prompt(classification)

      response = call_groq_api(prompt, max_tokens: 300, temperature: 0.7)

      return { error: response[:error] } if response[:error]

      parse_reply(response[:message])
    end

    def build_reply_prompt(classification)
      contact_name = conversation.contact.name || 'there'
      
      context = {
        greeting: "Respond warmly and professionally. Keep it brief and friendly.",
        product_inquiry: "Provide helpful information about products. Be specific and informative. If you don't have exact details, acknowledge that an agent will provide more information.",
        support: "Acknowledge the issue and let them know an agent will assist shortly.",
        complaint: "Show empathy and assure them their concern is being addressed.",
        other: "Provide a helpful, professional response."
      }

      <<~PROMPT
        You are a customer service assistant for #{account.name}.

        Customer message: "#{message.content}"

        Message type: #{classification[:type]}
        Instructions: #{context[classification[:type].to_sym]}

        Conversation history:
        #{get_conversation_context}

        Contact name: #{contact_name}

        Generate a helpful, professional reply. Keep it concise (2-3 sentences max).
        Use the customer's name if appropriate.

        Respond with ONLY the reply text, no JSON or formatting.
      PROMPT
    end

    def call_groq_api(prompt, max_tokens: 200, temperature: 0.3)
      require 'net/http'
      require 'json'

      endpoint = ai_config.api_endpoint || 'https://api.groq.com/openai/v1'
      model = ai_config.model_name || 'llama-3.1-70b-versatile'

      uri = URI("#{endpoint}/chat/completions")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ai_config.api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: model,
        messages: [
          { role: 'system', content: 'You are a helpful customer service assistant.' },
          { role: 'user', content: prompt }
        ],
        temperature: temperature,
        max_tokens: max_tokens
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 20) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        result = JSON.parse(response.body)
        { message: result.dig('choices', 0, 'message', 'content') }
      else
        { error: "Groq API error: #{response.code}" }
      end
    rescue StandardError => e
      { error: "API call failed: #{e.message}" }
    end

    def parse_classification(ai_message)
      json_match = ai_message.match(/\{.*\}/m)
      return fallback_classification unless json_match

      parsed = JSON.parse(json_match[0])
      type = parsed['type']&.to_sym

      unless MESSAGE_TYPES.keys.include?(type)
        return fallback_classification
      end

      {
        type: type,
        confidence: parsed['confidence'].to_i,
        reason: parsed['reason']
      }
    rescue JSON::ParserError
      fallback_classification
    end

    def fallback_classification
      # Simple keyword-based classification
      content = message.content.to_s.downcase

      type = if content.match?(/\b(hi|hello|hey|good morning|good afternoon)\b/)
               :greeting
             elsif content.match?(/\b(product|price|cost|buy|purchase|available|stock)\b/)
               :product_inquiry
             elsif content.match?(/\b(help|support|issue|problem|not working)\b/)
               :support
             elsif content.match?(/\b(complaint|angry|disappointed|terrible|bad)\b/)
               :complaint
             else
               :other
             end

      {
        type: type,
        confidence: 60,
        reason: 'Keyword-based classification'
      }
    end

    def parse_reply(ai_message)
      # Clean up the reply
      content = ai_message.strip
      
      # Remove any JSON formatting if present
      content = content.gsub(/^\{.*\}$/m, '').strip
      
      { content: content }
    end

    def should_auto_approve?(message_type)
      MESSAGE_TYPES.dig(message_type.to_sym, :auto_approve) || false
    end

    def send_reply(content)
      # Create outgoing message
      Messages::MessageBuilder.new(
        user: nil, # Bot message
        conversation: conversation,
        message_type: :outgoing,
        content: content,
        private: false,
        content_attributes: {
          ai_generated: true,
          auto_approved: true
        }
      ).perform
    end

    def queue_for_approval(content, classification)
      # Store in conversation additional_attributes for now
      # In a full implementation, this would go to a separate approval queue
      conversation.additional_attributes ||= {}
      conversation.additional_attributes['pending_ai_reply'] = {
        content: content,
        type: classification[:type],
        confidence: classification[:confidence],
        created_at: Time.current.iso8601,
        message_id: message.id
      }
      conversation.save!
    end
  end
end
