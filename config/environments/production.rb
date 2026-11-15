require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Ficheros escaneados en disco (config/storage.yml): storage/ o la carpeta de STORAGE_PATH.
  config.active_storage.service = :local

  # Caché compartida y duradera (D98): Solid Cache, en la base de datos (config/cache.yml). Guarda los
  # contadores de los límites de intentos, que así son comunes a todos los procesos y servidores y no se
  # pierden al desplegar.
  config.cache_store = :solid_cache_store

  # Proxies de confianza (D98): las direcciones (o redes) de los proxies que no sean privadas, separadas por
  # comas. Así Rails toma la IP real del cliente de X-Forwarded-For (los límites de intentos van por IP).
  if ENV["TRUSTED_PROXIES"].present?
    config.action_dispatch.trusted_proxies =
      ENV["TRUSTED_PROXIES"].split(",").map { |direccion| IPAddr.new(direccion.strip) } +
      ActionDispatch::RemoteIp::TRUSTED_PROXIES
  end

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates (el primer dominio de APP_HOST, por HTTPS).
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com").split(",").first.strip,
                                                protocol: "https" }

  # Correo (confirmación del email, recuperación de la clave y avisos de seguridad) por SMTP, con los datos
  # del servidor en variables de entorno (ver README, «Producción») y siempre cifrado (config/correo_smtp.rb,
  # D104). Sin SMTP_ADDRESS no se envía ningún correo.
  if ENV["SMTP_ADDRESS"].present?
    require_relative "../correo_smtp"
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = CorreoSmtp.ajustes
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks: solo se atienden peticiones
  # dirigidas a los dominios de APP_HOST (separados por comas, p. ej. "fisios.example.es"). Es
  # obligatorio: sin él la aplicación no arranca, para no quedarse sin esta protección por un olvido.
  # La única excepción es compilar los assets (assets:precompile con SECRET_KEY_BASE_DUMMY).
  if ENV["APP_HOST"].present?
    config.hosts = ENV["APP_HOST"].split(",").map(&:strip)
    # Skip DNS rebinding protection for the default health check endpoint.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  elsif ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise "Falta la variable de entorno APP_HOST con el dominio de la aplicación (ver README, «Producción»)."
  end
end
