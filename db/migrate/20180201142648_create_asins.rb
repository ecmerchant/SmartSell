class CreateAsins < ActiveRecord::Migration[5.0]
  def change
    create_table :asins do |t|
      t.string :user
      t.string :rasin
      t.string :nasin

      t.timestamps
    end
  end
end
