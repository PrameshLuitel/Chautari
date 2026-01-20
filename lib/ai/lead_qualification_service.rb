# frozen_string_literal: true

module Ai
  class LeadQualificationService
    pattr_initialize [:contact!, :account!]

    # Main method to analyze and qualify a lead
    def perform
      return { success: false, error: 'AI not configured' } unless ai_config

      # Get or create lead score
      lead_score = contact.lead_score || contact.create_lead_score!(
        account: account,
        score: 0,
        category: :new_lead
      )

      # Analyze the contact
      analysis_result = analyze_contact
      
      return { success: false, error: analysis_result[:error] } if analysis_result[:error]

      # Update score and category
      new_score = analysis_result[:score]
      new_category = determine_category(analysis_result)

      # Update lead score
      lead_score.update_score!(
        new_score,
        analysis_data: {
          notes: analysis_result[:notes],
          factors: analysis_result[:factors],
          analyzed_at: Time.current.iso8601
        }
      )

      # Update category if changed
      if new_category.to_s != lead_score.category
        lead_score.update_category!(
          new_category,
          notes: analysis_result[:category_reason]
        )
      end

      {
        success: true,
        score: new_score,
        category: new_category,
        notes: analysis_result[:notes]
      }
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      { success: false, error: e.message }
    end

    private

    def ai_config
      @ai_config ||= account.ai_configs.find_by(provider: 'groq', status: 'active')
    end

    def analyze_contact
      # Gather contact data
      conversation_history = get_conversation_history
      engagement_metrics = calculate_engagement_metrics
      sentiment_analysis = analyze_sentiment(conversation_history)
      
      # Build AI prompt
      prompt = build_analysis_prompt(conversation_history, engagement_metrics, sentiment_analysis)

      # Call Groq API
      response = call_groq_api(prompt)

      return { error: response[:error] } if response[:error]

      # Parse AI response
      parse_ai_response(response[:message], engagement_metrics)
    end

    def get_conversation_history
      conversations = contact.conversations
                             .where(account: account)
                             .order(created_at: :desc)
                             .limit(10)

      conversations.map do |conv|
        {
          id: conv.id,
          status: conv.status,
          created_at: conv.created_at,
          messages: conv.messages.order(created_at: :asc).limit(20).map do |msg|
            {
              content: msg.content,
              message_type: msg.message_type,
              created_at: msg.created_at,
              sender_type: msg.sender_type
            }
          end
        }
      end
    end

    def calculate_engagement_metrics
      conversations = contact.conversations.where(account: account)
      messages = contact.messages.where(account: account)

      {
        total_conversations: conversations.count,
        total_messages: messages.count,
        avg_response_time: calculate_avg_response_time(conversations),
        last_activity: contact.last_activity_at,
        days_since_first_contact: (Time.current - contact.created_at).to_i / 86_400,
        resolved_conversations: conversations.where(status: 'resolved').count
      }
    end

    def calculate_avg_response_time(conversations)
      response_times = conversations.map do |conv|
        first_customer_msg = conv.messages.where(message_type: 'incoming').first
        first_agent_msg = conv.messages.where(message_type: 'outgoing').first
        
        next unless first_customer_msg && first_agent_msg
        
        (first_agent_msg.created_at - first_customer_msg.created_at).to_i
      end.compact

      return 0 if response_times.empty?

      response_times.sum / response_times.size
    end

    def analyze_sentiment(conversation_history)
      # Simple sentiment analysis based on keywords
      positive_keywords = %w[great excellent love happy satisfied thanks thank]
      negative_keywords = %w[bad terrible hate unhappy disappointed complaint]
      payment_keywords = %w[pay payment price cost invoice quote bill purchase buy order]
      
      all_messages = conversation_history.flat_map { |c| c[:messages].map { |m| m[:content].to_s.downcase } }
      
      {
        positive_count: all_messages.sum { |msg| positive_keywords.count { |kw| msg.include?(kw) } },
        negative_count: all_messages.sum { |msg| negative_keywords.count { |kw| msg.include?(kw) } },
        payment_mentions: all_messages.sum { |msg| payment_keywords.count { |kw| msg.include?(kw) } }
      }
    end

    def build_analysis_prompt(conversation_history, engagement_metrics, sentiment)
      recent_messages = conversation_history.first(3).flat_map { |c| c[:messages].last(5) }
                                            .map { |m| "#{m[:sender_type]}: #{m[:content]}" }
                                            .join("\n")

      <<~PROMPT
        You are a lead qualification AI assistant. Analyze this contact and provide a lead score and category.

        Contact Information:
        - Name: #{contact.name}
        - Email: #{contact.email}
        - Phone: #{contact.phone_number}
        - First Contact: #{contact.created_at.strftime('%Y-%m-%d')}
        - Days Active: #{engagement_metrics[:days_since_first_contact]}

        Engagement Metrics:
        - Total Conversations: #{engagement_metrics[:total_conversations]}
        - Total Messages: #{engagement_metrics[:total_messages]}
        - Resolved Conversations: #{engagement_metrics[:resolved_conversations]}
        - Last Activity: #{engagement_metrics[:last_activity]&.strftime('%Y-%m-%d %H:%M') || 'Never'}

        Sentiment Analysis:
        - Positive Indicators: #{sentiment[:positive_count]}
        - Negative Indicators: #{sentiment[:negative_count]}
        - Payment Mentions: #{sentiment[:payment_mentions]}

        Recent Conversation Sample:
        #{recent_messages}

        Based on this information, provide:
        1. A lead score (0-100)
        2. A category (new_lead, hot_lead, payments, existing_customer)
        3. Brief qualification notes (2-3 sentences)
        4. Reasoning for the category choice

        Category Guidelines:
        - new_lead: First-time contact, minimal engagement, exploratory questions
        - hot_lead: High engagement (score 70+), purchase intent, budget discussion, urgency
        - payments: Payment keywords, pricing negotiation, invoice/quote requests
        - existing_customer: Previous purchases, support requests, repeat inquiries

        Respond in JSON format:
        {
          "score": 75,
          "category": "hot_lead",
          "notes": "High engagement with strong purchase intent...",
          "category_reason": "Multiple conversations with pricing discussions..."
        }
      PROMPT
    end

    def call_groq_api(prompt)
      require 'net/http'
      require 'json'

      endpoint = ai_config.api_endpoint || 'https://api.groq.com/openai/v1'
      model = ai_config.ai_model || 'llama-3.1-70b-versatile'

      uri = URI("#{endpoint}/chat/completions")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ai_config.api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: model,
        messages: [
          { role: 'system', content: 'You are a lead qualification expert. Always respond with valid JSON.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 500
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        result = JSON.parse(response.body)
        { message: result.dig('choices', 0, 'message', 'content') }
      else
        { error: "Groq API error: #{response.code} - #{response.body}" }
      end
    rescue StandardError => e
      { error: "API call failed: #{e.message}" }
    end

    def parse_ai_response(ai_message, engagement_metrics)
      # Extract JSON from AI response
      json_match = ai_message.match(/\{.*\}/m)
      return fallback_analysis(engagement_metrics) unless json_match

      parsed = JSON.parse(json_match[0])

      {
        score: parsed['score'].to_i.clamp(0, 100),
        category: parsed['category'],
        notes: parsed['notes'],
        category_reason: parsed['category_reason'],
        factors: {
          engagement: engagement_metrics[:total_conversations],
          messages: engagement_metrics[:total_messages],
          response_time: engagement_metrics[:avg_response_time]
        }
      }
    rescue JSON::ParserError
      fallback_analysis(engagement_metrics)
    end

    def fallback_analysis(engagement_metrics)
      # Fallback scoring if AI fails
      score = calculate_fallback_score(engagement_metrics)
      
      {
        score: score,
        category: determine_fallback_category(score, engagement_metrics),
        notes: 'Automated analysis based on engagement metrics',
        category_reason: 'Determined by engagement patterns',
        factors: engagement_metrics
      }
    end

    def calculate_fallback_score(metrics)
      score = 0
      score += [metrics[:total_conversations] * 10, 30].min
      score += [metrics[:total_messages] * 2, 30].min
      score += metrics[:resolved_conversations] * 5
      score += 20 if metrics[:last_activity] && metrics[:last_activity] > 7.days.ago
      score.clamp(0, 100)
    end

    def determine_fallback_category(score, metrics)
      return :existing_customer if metrics[:resolved_conversations] > 2
      return :hot_lead if score >= 70
      return :new_lead if metrics[:total_conversations] <= 1
      
      :new_lead
    end

    def determine_category(analysis_result)
      category = analysis_result[:category]&.to_sym
      
      # Validate category
      return category if LeadScore.categories.keys.include?(category.to_s)
      
      # Fallback to score-based category
      score = analysis_result[:score]
      return :hot_lead if score >= 70
      return :new_lead if score < 40
      
      :new_lead
    end
  end
end
