# Token de sesión de cada osteópata (D99): forma parte de lo que Devise guarda en la cookie de sesión, y al
# cerrar sesión se cambia. Así, una cookie copiada deja de valer en cuanto su dueño cierra sesión.
class TokenDeSesionDeLosOsteopatas < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :token_sesion, :string
  end
end
