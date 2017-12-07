class CreateRules < ActiveRecord::Migration[5.0]
  def change
    create_table :rules do |t|
      t.text :user
      t.text :url
      t.text :price_t
      t.text :title_t
      t.text :fix_t
      t.text :key_t

      t.timestamps
    end
  end
end
