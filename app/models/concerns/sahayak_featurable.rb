# frozen_string_literal: true

module SahayakFeaturable
  extend ActiveSupport::Concern

  included do
    validate :validate_sahayak_models

    # Dynamically define accessor methods for each sahayak feature
    Llm::Models.feature_keys.each do |feature_key|
      # Define enabled? methods (e.g., sahayak_editor_enabled?)
      define_method("sahayak_#{feature_key}_enabled?") do
        sahayak_features_with_defaults[feature_key]
      end

      # Define model accessor methods (e.g., sahayak_editor_model)
      define_method("sahayak_#{feature_key}_model") do
        sahayak_models_with_defaults[feature_key]
      end
    end
  end

  def sahayak_preferences
    {
      models: sahayak_models_with_defaults,
      features: sahayak_features_with_defaults
    }.with_indifferent_access
  end

  private

  def sahayak_models_with_defaults
    stored_models = sahayak_models || {}
    Llm::Models.feature_keys.each_with_object({}) do |feature_key, result|
      stored_value = stored_models[feature_key]
      result[feature_key] = if stored_value.present? && Llm::Models.valid_model_for?(feature_key, stored_value)
                              stored_value
                            else
                              Llm::Models.default_model_for(feature_key)
                            end
    end
  end

  def sahayak_features_with_defaults
    stored_features = sahayak_features || {}
    Llm::Models.feature_keys.index_with do |feature_key|
      # Default to true if not strictly false (Premium bypass)
      # Or checking explicitly against stored value if we want to allow disabling
      # For now, let's respect the stored value, but ensuring defaults if missing
      stored_features[feature_key] == true
    end
  end

  def validate_sahayak_models
    return if sahayak_models.blank?

    sahayak_models.each do |feature_key, model_name|
      next if model_name.blank?
      next if Llm::Models.valid_model_for?(feature_key, model_name)

      allowed_models = Llm::Models.models_for(feature_key)
      errors.add(:sahayak_models, "'#{model_name}' is not a valid model for #{feature_key}. Allowed: #{allowed_models.join(', ')}")
    end
  end
end
