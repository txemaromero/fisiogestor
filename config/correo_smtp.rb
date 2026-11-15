# Datos del servidor de correo (SMTP) de producción, de las variables de entorno (ver README, «Producción»).
# Lo usa config/environments/production.rb; va aparte para poder probarlo
# (test/integration/configuracion_seguridad_test.rb).
module CorreoSmtp
  # Puerto de SMTP con TLS desde el principio (SMTPS). En los demás (587 por defecto) se usa STARTTLS.
  PUERTO_TLS = 465

  # La conexión va siempre cifrada (D104): STARTTLS obligatorio (no «si el servidor lo ofrece», que alguien
  # en medio de la red puede quitar para leer la clave del SMTP y los enlaces de los correos) o, en el puerto
  # 465, TLS desde el principio. Si no se puede cifrar, el correo no se envía. Se comprueba el certificado.
  def self.ajustes(entorno = ENV)
    puerto = entorno.fetch("SMTP_PORT", "587").to_i
    cifrado = puerto == PUERTO_TLS ? { tls: true } : { enable_starttls: :always }
    { address: entorno["SMTP_ADDRESS"], port: puerto, user_name: entorno["SMTP_USER_NAME"],
      password: entorno["SMTP_PASSWORD"], authentication: :plain, openssl_verify_mode: "peer", **cifrado }
  end
end
