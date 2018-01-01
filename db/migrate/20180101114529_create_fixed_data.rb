class CreateFixedData < ActiveRecord::Migration[5.0]
  def change
    create_table :fixed_data do |t|
      t.text :list

      t.timestamps
    end
  end
end
