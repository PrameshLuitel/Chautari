class AddSahayakToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :sahayak_models, :jsonb, default: {}, null: false
    add_column :accounts, :sahayak_features, :jsonb, default: {}, null: false
  end
end
