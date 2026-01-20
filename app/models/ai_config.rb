# == Schema Information
#
# Table name: ai_configs
#
#  id               :bigint           not null, primary key
#  ai_model_name    :string
#  api_endpoint     :string
#  api_key          :string
#  features_enabled :jsonb            not null
#  provider         :integer          default("groq"), not null
#  settings         :jsonb            not null
#  status           :integer          default("active"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_ai_configs_on_account_id               (account_id)
#  index_ai_configs_on_account_id_and_provider  (account_id,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AiConfig < ApplicationRecord
  # Encryption for API keys
  encrypts :api_key, deterministic: true if Chatwoot.encryption_configured?

  belongs_to :account

  # Provider enum - Groq is default
  enum provider: {
    groq: 0,
    openai: 1,
    anthropic: 2,
    custom: 3
  }, _default: :groq

  # Status enum
  enum status: {
    active: 0,
    inactive: 1,
    error: 2
  }, _default: :active

  # Validations
  validates :account_id, presence: true
  validates :provider, presence: true
  validates :api_key, presence: true
  validates :account_id, uniqueness: { scope: :provider }

  # Default values
  after_initialize :set_defaults, if: :new_record?

  # Groq model options
  GROQ_MODELS = [
    'llama-3.1-70b-versatile',
    'llama-3.1-8b-instant',
    'llama-3.2-90b-text-preview',
    'mixtral-8x7b-32768',
    'gemma2-9b-it'
  ].freeze

  # OpenAI model options (for future)
  OPENAI_MODELS = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo'
  ].freeze

  # Get default endpoint for provider
  def default_endpoint
    case provider.to_sym
    when :groq
      'https://api.groq.com/openai/v1'
    when :openai
      'https://api.openai.com/v1'
    when :anthropic
      'https://api.anthropic.com/v1'
    else
      nil
    end
  end

  # Get available models for provider
  def available_models
    case provider.to_sym
    when :groq
      GROQ_MODELS
    when :openai
      OPENAI_MODELS
    else
      []
    end
  end

  # Test API connection
  def test_connection
    return { success: false, error: 'API key not configured' } if api_key.blank?

    endpoint = api_endpoint.presence || default_endpoint
    model = ai_model_name.presence || available_models.first

    begin
      require 'net/http'
      require 'json'

      uri = URI("#{endpoint}/models")
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 10) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        { success: true, message: 'Connection successful' }
      else
        { success: false, error: "API returned #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end

  private

  def set_defaults
    self.api_endpoint ||= default_endpoint
    self.ai_model_name ||= available_models.first
    self.settings ||= {}
    self.features_enabled ||= []
  end
end
