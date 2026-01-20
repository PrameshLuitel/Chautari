class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :cost, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: 'USD', null: false
      t.string :image_url
      t.references :account, null: false, foreign_key: true
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end
    add_index :products, :metadata, using: :gin
  end
end
