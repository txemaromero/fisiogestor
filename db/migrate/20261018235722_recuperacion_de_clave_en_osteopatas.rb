# Recuperación de la clave por email (Devise :recoverable, D76). Devise guarda el token cifrado.
class RecuperacionDeClaveEnOsteopatas < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :reset_password_token, :string
    add_column :osteopaths, :reset_password_sent_at, :datetime
    add_index :osteopaths, :reset_password_token, unique: true
  end
end
