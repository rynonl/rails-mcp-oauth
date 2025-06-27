class CreateOAuthSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :o_auth_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :access_token
      t.text :refresh_token
      t.text :permissions
      t.datetime :expires_at
      t.string :state

      t.timestamps
    end
  end
end
