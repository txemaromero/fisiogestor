# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # Datos personales y de salud de los pacientes: no deben quedar en los logs.
  :nombre, :apellidos, :anyo_nacimiento, :sexo, :familiar, :tipo, :descripcion, :anamnesis, :motivo,
  :escala_dolor, :resumen, :escaneado, :archivo, :sesiones_json, :nueva_enfermedad, :disfunciones_somaticas,
  /\Aexamen_/, /\Ainspeccion_/,
  # Lo que se escribe en el buscador de pacientes (nombres).
  :busqueda,
  # La clave actual y los códigos del segundo factor (de la app y de recuperación) de sus formularios (D92), y
  # los textos de los casos clínicos y sus comentarios.
  :clave, :codigo, :titulo, :texto
]
