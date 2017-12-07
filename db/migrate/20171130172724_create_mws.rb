class CreateMws < ActiveRecord::Migration[5.0]
  def change
    create_table :mws do |t|
      t.text :User
      t.text :AWSkey
      t.text :Skey
      t.text :SellerId

      t.timestamps
    end
  end
end
