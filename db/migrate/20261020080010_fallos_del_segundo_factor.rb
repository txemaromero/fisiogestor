# Códigos del segundo factor incorrectos seguidos y hasta cuándo no se aceptan más (D92). Se guardan en la
# base de datos y no en la sesión: la sesión es una cookie que el navegador puede volver a enviar tal cual.
class FallosDelSegundoFactor < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :otp_fallos, :integer, default: 0, null: false
    add_column :osteopaths, :otp_bloqueado_hasta, :datetime
  end
end
