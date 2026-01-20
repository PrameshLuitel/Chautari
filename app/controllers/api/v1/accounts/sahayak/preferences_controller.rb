class Api::V1::Accounts::Sahayak::PreferencesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    @current_account.update!(sahayak_params) if sahayak_params.present?
    update_groq_config if params[:groq_config].present?

    render json: preferences_payload
  end

  private

  def preferences_payload
    {
      providers: Llm::Models.providers,
      models: Llm::Models.models,
      features: features_with_account_preferences,
      groq_config: groq_config_payload
    }
  end

  def groq_config_payload
    config = @current_account.ai_configs.find_or_initialize_by(provider: 'groq')
    {
      id: config.id,
      api_key: config.api_key.present? ? '********************************' : nil,
      api_endpoint: config.api_endpoint,
      ai_model_name: config.ai_model_name
    }
  end

  def update_groq_config
    config = @current_account.ai_configs.find_or_initialize_by(provider: 'groq')
    config_params = params.require(:groq_config).permit(:api_key, :api_endpoint, :ai_model_name)
    
    # Don't overwrite api_key if it's the masked value
    config_params.delete(:api_key) if config_params[:api_key] == '********************************'
    
    config.update!(config_params)
  end

  def authorize_account_update
    authorize @current_account, :update?
  end

  def sahayak_params
    permitted = {}
    permitted[:sahayak_models] = merged_sahayak_models if params[:sahayak_models].present?
    permitted[:sahayak_features] = merged_sahayak_features if params[:sahayak_features].present?
    permitted
  end

  def merged_sahayak_models
    existing_models = @current_account.sahayak_models || {}
    existing_models.merge(permitted_sahayak_models)
  end

  def merged_sahayak_features
    existing_features = @current_account.sahayak_features || {}
    existing_features.merge(permitted_sahayak_features)
  end

  def permitted_sahayak_models
    params.require(:sahayak_models).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def permitted_sahayak_features
    params.require(:sahayak_features).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def features_with_account_preferences
    preferences = Current.account.sahayak_preferences
    account_features = preferences[:features] || {}
    account_models = preferences[:models] || {}

    Llm::Models.feature_keys.index_with do |feature_key|
      config = Llm::Models.feature_config(feature_key)
      config.merge(
        enabled: account_features[feature_key] == true,
        selected: account_models[feature_key] || config[:default]
      )
    end
  end
end
