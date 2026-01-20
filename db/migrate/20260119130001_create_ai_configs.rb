class CreateAiConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :provider, default: 0, null: false
      t.string :ai_model
      t.string :api_key
      t.string :api_endpoint
      t.jsonb :settings, default: {}, null: false
      t.jsonb :features_enabled, default: [], null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :ai_configs, [:account_id, :provider], unique: true
  end
end
