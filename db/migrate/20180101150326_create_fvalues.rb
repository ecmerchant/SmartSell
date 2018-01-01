class CreateFvalues < ActiveRecord::Migration[5.0]
  def change
    create_table :fvalues do |t|
      t.string :user
      t.text :list

      t.timestamps
    end
  end
end
