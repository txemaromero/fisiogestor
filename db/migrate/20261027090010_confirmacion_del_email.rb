# Confirmación del email al registrarse (D103): las columnas de Devise :confirmable. Sin unconfirmed_email,
# porque la aplicación no deja cambiar el email. Las cuentas que ya existían se dan por confirmadas, para no
# dejar fuera a nadie.
class ConfirmacionDelEmail < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :confirmation_token, :string
    add_column :osteopaths, :confirmed_at, :datetime
    add_column :osteopaths, :confirmation_sent_at, :datetime
    add_index :osteopaths, :confirmation_token, unique: true

    up_only { execute "UPDATE osteopaths SET confirmed_at = created_at" }
  end
end
