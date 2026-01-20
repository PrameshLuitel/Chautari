class Api::V1::Accounts::ProductBundlesController < Api::V1::Accounts::BaseController
  before_action :fetch_product_bundle, only: [:show, :update, :destroy]

  def index
    @product_bundles = Current.account.product_bundles.order(created_at: :desc)
    render json: @product_bundles
  end

  def show
    render json: @product_bundle.as_json(include: :products)
  end

  def create
    @product_bundle = Current.account.product_bundles.new(product_bundle_params)
    
    if @product_bundle.save
      render json: @product_bundle, status: :created
    else
      render_error_response(@product_bundle)
    end
  end

  def update
    if @product_bundle.update(product_bundle_params)
      render json: @product_bundle
    else
      render_error_response(@product_bundle)
    end
  end

  def destroy
    @product_bundle.destroy
    head :ok
  end

  private

  def fetch_product_bundle
    @product_bundle = Current.account.product_bundles.find(params[:id])
  end

  def product_bundle_params
    params.require(:product_bundle).permit(
      :name, :description, :price, product_ids: []
    )
  end
end
