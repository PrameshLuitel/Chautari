class Api::V1::Accounts::ProductsController < Api::V1::Accounts::BaseController
  before_action :fetch_product, except: [:index, :create]

  def index
    @products = Current.account.products.order(created_at: :desc)
    render json: @products
  end

  def show
    render json: @product
  end

  def create
    @product = Current.account.products.new(product_params)
    if @product.save
      render json: @product
    else
      render json: { error: @product.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      render json: @product
    else
      render json: { error: @product.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy!
    head :ok
  end

  private

  def fetch_product
    @product = Current.account.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :cost, :currency, :image_url, metadata: {})
  end
end
