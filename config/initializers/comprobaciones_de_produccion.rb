# Comprobaciones al arrancar en producción (D98), además de la de APP_HOST (config/environments/production.rb).
# No se hacen al compilar los assets (assets:precompile con SECRET_KEY_BASE_DUMMY), que no usa la base de
# datos ni los ficheros.
module ComprobacionesDeProduccion
  # Modos de PostgreSQL que pueden conectar sin cifrar.
  MODOS_SIN_CIFRAR = %w[disable allow prefer].freeze

  # La conexión con la base de datos va cifrada, salvo que se permita a propósito (pruebas locales). Se mira
  # el modo con el que de verdad se conecta (D104): el de database.yml (PGSSLMODE, «require» si no se da) o el
  # de DATABASE_URL, que manda si lo lleva (?sslmode=...). Sin ninguno, PostgreSQL usa PGSSLMODE o «prefer».
  def self.ssl_de_la_base_de_datos!(configuracion = Rails.application.config.database_configuration, entorno = ENV)
    modo = modo_ssl_de_la_base_de_datos(configuracion, entorno)
    return unless MODOS_SIN_CIFRAR.include?(modo) && entorno["PERMITIR_BD_SIN_SSL"] != "1"

    raise "La conexión con la base de datos usa sslmode=#{modo} (de PGSSLMODE o de DATABASE_URL), que permite " \
          "conectar sin cifrar: son datos de salud. Usa «require» o «verify-full» (o PERMITIR_BD_SIN_SSL=1 solo " \
          "para pruebas locales). Ver README, «Producción»."
  end

  def self.modo_ssl_de_la_base_de_datos(configuracion, entorno)
    produccion = ActiveRecord::DatabaseConfigurations.new(configuracion).configs_for(env_name: "production", name: "primary")
    (produccion&.configuration_hash&.[](:sslmode) || entorno["PGSSLMODE"] || "prefer").to_s
  end

  # Aviso si la carpeta de los ficheros escaneados (datos de salud) la pueden leer otros usuarios del
  # servidor. Solo avisa: los permisos son cosa de quien administra el servidor.
  def self.permisos_de_storage(carpeta)
    return unless File.directory?(carpeta) && !Gem.win_platform?

    modo = File.stat(carpeta).mode & 0o777
    return if (modo & 0o077).zero?

    format("La carpeta de los ficheros escaneados (%s) tiene permisos %o: otros usuarios del servidor pueden " \
           "leerla. Deberían ser 700 (solo el usuario de la aplicación).", carpeta, modo)
  end
end

if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  ComprobacionesDeProduccion.ssl_de_la_base_de_datos!
  aviso = ComprobacionesDeProduccion.permisos_de_storage(ENV.fetch("STORAGE_PATH") { Rails.root.join("storage").to_s })
  Rails.logger.warn(aviso) if aviso
end
