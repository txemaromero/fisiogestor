# Claves de Active Record Encryption, con las que se cifra el secreto TOTP del segundo factor (D84).
# Se derivan de secret_key_base, así que no hacen falta variables de entorno ni credenciales nuevas.
# Ojo: si se cambia secret_key_base, los secretos guardados no se pueden descifrar y cada osteópata tiene
# que volver a dar de alta su segundo factor (bin/rails dos_factores:restablecer EMAIL=...).
generador = Rails.application.key_generator
cifrado = Rails.application.config.active_record.encryption
cifrado.primary_key = generador.generate_key("active_record_encryption/primary_key", 32).unpack1("H*")
cifrado.deterministic_key = generador.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*")
cifrado.key_derivation_salt = generador.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
