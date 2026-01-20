# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
#
#  id                    :integer          not null, primary key
#  auto_resolve_duration :integer
#  custom_attributes     :jsonb
#  domain                :string(100)
#  feature_flags         :bigint           default(0), not null
#  internal_attributes   :jsonb            not null
#  limits                :jsonb
#  locale                :integer          default("en")
#  name                  :string           not null
#  sahayak_features      :jsonb            not null
#  sahayak_models        :jsonb            not null
#  settings              :jsonb
#  status                :integer          default("active")
#  support_email         :string(100)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  ai_config_id          :bigint
#
# Indexes
#
#  index_accounts_on_ai_config_id  (ai_config_id)
#  index_accounts_on_status        (status)
#
# Foreign Keys
#
#  fk_rails_...  (ai_config_id => ai_configs.id)
#
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    status { 'active' }
    domain { 'test.com' }
    support_email { 'support@test.com' }
  end
end
