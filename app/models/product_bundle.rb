# == Schema Information
#
# Table name: product_bundles
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  price       :decimal(10, 2)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_product_bundles_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ProductBundle < ApplicationRecord
  belongs_to :account
  has_many :product_bundle_items, dependent: :destroy
  has_many :products, through: :product_bundle_items

  validates :name, presence: true
  validates :account_id, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Calculate total price dynamically if price is not set
  def total_price
    price || products.sum(:price)
  end
end
