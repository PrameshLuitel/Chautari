class CreateProductBundles < ActiveRecord::Migration[7.0]
  def change
    create_table :product_bundles do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    create_table :product_bundle_items do |t|
      t.references :product_bundle, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :product_bundle_items, [:product_bundle_id, :product_id], unique: true
  end
end
