# frozen_string_literal: true

class DeviseCreateOsteopaths < ActiveRecord::Migration[8.1]
  def change
    create_table :osteopaths do |t|
      t.string :nombre,    null: false
      t.string :apellidos, null: false

      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.timestamps null: false
    end

    add_index :osteopaths, :email, unique: true
  end
end
