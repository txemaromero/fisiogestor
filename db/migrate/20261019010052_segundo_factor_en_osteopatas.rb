# Segundo factor de autenticación obligatorio (D84): el secreto TOTP (cifrado con Active Record
# Encryption), cuándo se activó, el último paso de tiempo usado (para que un código no valga dos veces) y
# las huellas (HMAC) de los códigos de recuperación que quedan.
class SegundoFactorEnOsteopatas < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :otp_secret, :text
    add_column :osteopaths, :otp_activado_at, :datetime
    add_column :osteopaths, :otp_ultimo_paso, :bigint
    add_column :osteopaths, :codigos_recuperacion, :text
  end
end
