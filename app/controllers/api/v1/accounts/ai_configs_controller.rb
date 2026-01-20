class Api::V1::Accounts::AiConfigsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_ai_config, only: [:show, :update, :destroy, :test_connection]

  def index
    @ai_configs = Current.account.ai_configs
    render json: @ai_configs
  end

  def show
    render json: @ai_config
  end

  def create
    @ai_config = Current.account.ai_configs.new(ai_config_params)

    if @ai_config.save
      render json: @ai_config, status: :created
    else
      render json: { errors: @ai_config.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @ai_config.update(ai_config_params)
      render json: @ai_config
    else
      render json: { errors: @ai_config.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @ai_config.destroy
    head :no_content
  end

  def test_connection
    result = @ai_config.test_connection

    if result[:success]
      render json: { success: true, message: result[:message] }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  def providers
    providers_list = AiConfig.providers.keys.map do |provider|
      {
        value: provider,
        label: provider.titleize,
        models: (provider == 'groq' ? AiConfig::GROQ_MODELS : nil),
        default_endpoint: case provider
                          when 'groq' then 'https://api.groq.com/openai/v1'
                          when 'openai' then 'https://api.openai.com/v1'
                          when 'anthropic' then 'https://api.anthropic.com/v1'
                          else nil
                          end
      }
    end

    render json: providers_list
  end

  private

  def set_ai_config
    @ai_config = Current.account.ai_configs.find(params[:id])
  end

  def ai_config_params
    params.require(:ai_config).permit(
      :provider,
      :api_key,
      :api_endpoint,
      :ai_model,
      :status,
      settings: {},
      features_enabled: []
    )
  end

  def check_authorization
    authorize(AiConfig)
  end
end
