# == Schema Information
#
# Table name: product_bundle_items
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  product_bundle_id :bigint           not null
#  product_id        :bigint           not null
#
# Indexes
#
#  index_product_bundle_items_on_account_id                        (account_id)
#  index_product_bundle_items_on_product_bundle_id                 (product_bundle_id)
#  index_product_bundle_items_on_product_bundle_id_and_product_id  (product_bundle_id,product_id) UNIQUE
#  index_product_bundle_items_on_product_id                        (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (product_bundle_id => product_bundles.id)
#  fk_rails_...  (product_id => products.id)
#
class ProductBundleItem < ApplicationRecord
  belongs_to :product_bundle
  belongs_to :product
  belongs_to :account

  validates :product_bundle_id, presence: true
  validates :product_id, presence: true
  validates :account_id, presence: true

  before_validation :set_account_id

  private

  def set_account_id
    self.account_id = product_bundle&.account_id
  end
end
