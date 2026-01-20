# frozen_string_literal: true

module Ai
  class AutoLabelService
    pattr_initialize [:contact!, :account!]

    # Lead category labels (titles must match label validation: letters, numbers, hyphens, underscores only)
    LEAD_LABELS = {
      new_lead: { title: 'new-lead', color: '#3B82F6', description: '🆕 First-time contact, initial inquiry stage' },
      hot_lead: { title: 'hot-lead', color: '#EF4444', description: '🔥 High engagement, strong purchase intent' },
      payments: { title: 'payments', color: '#10B981', description: '💰 Payment/negotiation stage' },
      existing_customer: { title: 'existing-customer', color: '#F59E0B', description: '⭐ Previous purchase, repeat customer' }
    }.freeze

    def perform
      return { success: false, error: 'AI not configured' } unless ai_config
      return { success: false, error: 'Auto-labeling not enabled' } unless auto_labeling_enabled?

      # Ensure lead labels exist
      ensure_lead_labels_exist

      # Analyze contact and determine category
      analysis_result = analyze_contact_for_category

      return { success: false, error: analysis_result[:error] } if analysis_result[:error]

      # Get the appropriate label
      category = analysis_result[:category]
      label = find_or_create_lead_label(category)

      # Remove old lead category labels
      remove_old_lead_labels

      # Apply new label to contact's conversations
      apply_label_to_conversations(label)

      {
        success: true,
        category: category,
        label: label.title,
        confidence: analysis_result[:confidence],
        notes: analysis_result[:notes]
      }
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
      { success: false, error: e.message }
    end

    # Class method to ensure lead labels exist for an account
    def self.ensure_lead_labels_for_account(account)
      LEAD_LABELS.each do |_key, label_data|
        account.labels.find_or_create_by!(title: label_data[:title].downcase) do |label|
          label.color = label_data[:color]
          label.description = label_data[:description]
          label.show_on_sidebar = true
        end
      end
    end

    private

    def ai_config
      @ai_config ||= account.ai_configs.find_by(provider: 'groq', status: 'active')
    end

    def auto_labeling_enabled?
      # Sahayak Feature Check (renamed from lead_qualification if needed, but keeping consistent key for now)
      # Or checking sahayak_features
      account.sahayak_label_suggestion_enabled?
    end

    def ensure_lead_labels_exist
      self.class.ensure_lead_labels_for_account(account)
    end

    def find_or_create_lead_label(category)
      label_data = LEAD_LABELS[category.to_sym]
      account.labels.find_or_create_by!(title: label_data[:title].downcase) do |label|
        label.color = label_data[:color]
        label.description = label_data[:description]
        label.show_on_sidebar = true
      end
    end

    def remove_old_lead_labels
      # Get all lead label titles
      lead_label_titles = LEAD_LABELS.values.map { |l| l[:title].downcase }
      
      # Find all conversations for this contact
      contact.conversations.each do |conversation|
        # Remove any existing lead labels
        current_labels = conversation.label_list
        new_labels = current_labels.reject { |label| lead_label_titles.include?(label.downcase) }
        conversation.label_list = new_labels
        conversation.save if current_labels != new_labels
      end
    end

    def apply_label_to_conversations(label)
      # Apply label to all active conversations
      contact.conversations.where(status: ['open', 'pending']).each do |conversation|
        conversation.label_list.add(label.title)
        conversation.save
      end

      # Also apply to the most recent resolved conversation if within 7 days
      recent_resolved = contact.conversations.where(status: 'resolved')
                                            .where('updated_at > ?', 7.days.ago)
                                            .order(updated_at: :desc)
                                            .first
      
      if recent_resolved
        recent_resolved.label_list.add(label.title)
        recent_resolved.save
      end
    end

    def analyze_contact_for_category
      # Gather contact data
      conversation_history = get_conversation_history
      engagement_metrics = calculate_engagement_metrics
      
      # Build AI prompt
      prompt = build_category_prompt(conversation_history, engagement_metrics)

      # Call Groq API
      response = call_groq_api(prompt)

      return { error: response[:error] } if response[:error]

      # Parse AI response
      parse_category_response(response[:message])
    end

    def get_conversation_history
      conversations = contact.conversations
                             .where(account: account)
                             .order(created_at: :desc)
                             .limit(5)

      conversations.map do |conv|
        {
          status: conv.status,
          created_at: conv.created_at,
          messages: conv.messages.order(created_at: :asc).limit(10).map do |msg|
            {
              content: msg.content&.truncate(200),
              message_type: msg.message_type,
              sender_type: msg.sender_type
            }
          end
        }
      end
    end

    def calculate_engagement_metrics
      conversations = contact.conversations.where(account: account)
      
      {
        total_conversations: conversations.count,
        total_messages: contact.messages.where(account: account).count,
        last_activity: contact.last_activity_at,
        days_active: (Time.current - contact.created_at).to_i / 86_400,
        resolved_count: conversations.where(status: 'resolved').count,
        has_email: contact.email.present?,
        has_phone: contact.phone_number.present?
      }
    end

    def build_category_prompt(conversation_history, metrics)
      recent_messages = conversation_history.first(2).flat_map { |c| c[:messages].last(5) }
                                            .map { |m| "#{m[:sender_type]}: #{m[:content]}" }
                                            .join("\n")

      <<~PROMPT
        Analyze this contact and categorize them into ONE of these lead categories:

        Categories:
        1. new_lead - First-time contact, minimal engagement, exploratory questions
        2. hot_lead - High engagement, purchase intent, budget discussion, urgency signals
        3. payments - Payment keywords (pay, price, invoice, quote, cost, purchase), pricing negotiation
        4. existing_customer - Previous purchases, support requests, repeat inquiries, resolved conversations

        Contact Data:
        - Days Active: #{metrics[:days_active]}
        - Total Conversations: #{metrics[:total_conversations]}
        - Total Messages: #{metrics[:total_messages]}
        - Resolved Conversations: #{metrics[:resolved_count]}
        - Contact Info: #{metrics[:has_email] ? 'Email' : ''} #{metrics[:has_phone] ? 'Phone' : ''}

        Recent Messages:
        #{recent_messages.presence || 'No messages yet'}

        Respond ONLY with valid JSON:
        {
          "category": "hot_lead",
          "confidence": 85,
          "notes": "Brief reason for this categorization"
        }
      PROMPT
    end

    def call_groq_api(prompt)
      require 'net/http'
      require 'json'

      endpoint = ai_config.api_endpoint || 'https://api.groq.com/openai/v1'
      model = ai_config.ai_model_name || 'llama-3.1-70b-versatile'

      uri = URI("#{endpoint}/chat/completions")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ai_config.api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: model,
        messages: [
          { role: 'system', content: 'You are a lead categorization expert. Always respond with valid JSON only.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.2,
        max_tokens: 200
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

    def parse_category_response(ai_message)
      # Extract JSON from response
      json_match = ai_message.match(/\{.*\}/m)
      return fallback_categorization unless json_match

      parsed = JSON.parse(json_match[0])
      category = parsed['category']&.to_sym

      # Validate category
      unless LEAD_LABELS.keys.include?(category)
        return fallback_categorization
      end

      {
        category: category,
        confidence: parsed['confidence'].to_i,
        notes: parsed['notes']
      }
    rescue JSON::ParserError
      fallback_categorization
    end

    def fallback_categorization
      # Simple rule-based fallback
      metrics = calculate_engagement_metrics
      
      category = if metrics[:resolved_count] > 1
                   :existing_customer
                 elsif metrics[:total_conversations] > 3 && metrics[:total_messages] > 10
                   :hot_lead
                 elsif metrics[:total_conversations] <= 1
                   :new_lead
                 else
                   :new_lead
                 end

      {
        category: category,
        confidence: 50,
        notes: 'Automated categorization based on engagement metrics'
      }
    end
  end
end
