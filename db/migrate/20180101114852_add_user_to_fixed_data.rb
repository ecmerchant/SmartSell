class AddUserToFixedData < ActiveRecord::Migration[5.0]
  def change
    add_column :fixed_data, :user, :string
  end
end
