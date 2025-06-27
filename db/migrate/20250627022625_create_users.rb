class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :workos_id
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :profile_picture_url
      t.string :organization_id

      t.timestamps
    end
    add_index :users, :workos_id, unique: true
  end
end
