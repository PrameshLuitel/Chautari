# == Schema Information
#
# Table name: products
#
#  id          :bigint           not null, primary key
#  cost        :decimal(10, 2)   default(0.0), not null
#  currency    :string           default("USD"), not null
#  description :text
#  image_url   :string
#  metadata    :jsonb            not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_products_on_account_id  (account_id)
#  index_products_on_metadata    (metadata) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Product < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  # metadata can store: { discount_percent: 10, premium_charge: 5, tax_percent: 13 }
end
