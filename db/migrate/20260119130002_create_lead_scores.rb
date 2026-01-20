class CreateLeadScores < ActiveRecord::Migration[7.0]
  def change
    create_table :lead_scores do |t|
      t.references :contact, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :score, default: 0, null: false
      t.integer :category, default: 0, null: false
      t.jsonb :qualification_data, default: {}, null: false
      t.boolean :auto_qualified, default: false
      t.datetime :last_analyzed_at

      t.timestamps
    end

    add_index :lead_scores, [:contact_id, :account_id], unique: true
    add_index :lead_scores, :score
    add_index :lead_scores, :category
  end
end
